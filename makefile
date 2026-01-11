PLATFORM_AGNOSTIC_TARGETS += clean-fs-all clean-image-all

include src/make-helper-functions.mk

all: bin/$(IMAGE_NAME)

ifdef KERNEL_CONFIG_TARGET
KERNEL_TARGET=kernel/bin/$(KERNEL_CONFIG_TARGET)/.done
linux: $(KERNEL_TARGET)
	@true
$(KERNEL_TARGET):
	$(MAKE) -C kernel
else
linux:
	@true
endif

extra_packages:
	if [ "$(BUILD_PACKAGES)" != no ]; \
	  then $(MAKE) -C chroot-build-helper; \
	fi

clean-fs-all: build/bin/usernsexec
	uexec rm -rf "$(project_root)/build/"*.img

clean-fs: build/bin/usernsexec
	uexec rm -rf "$(project_root)/build/$(IMAGE_NAME)/"

clean-image-all:
	rm -f bin/*.img

clean-image:
	rm -f "bin/$(IMAGE_NAME)"

shell: enter-buildenv
enter-buildenv:
	export PROMPT_COMMAND='if [ -z "$$PS_SET" ]; then PS_SET=1; PS1="(buildenv) $$PS1"; fi'; \
	$(USER_SHELL)

build/$(DISTRO)-$(RELEASE)/deb/%.deb: | build/$(DISTRO)-$(RELEASE)/deb/.dir
	getdeb.sh "$@"

$(DEBOOTSTRAP_SCRIPT): build/$(DISTRO)-$(RELEASE)/deb/debootstrap.deb
	set -ex; \
	exec 8>"build/.debootstrap-$(DISTRO)-$(RELEASE).lock"; \
	flock 8; \
	if [ -e "$@" ]; then exit 0; fi; \
	rm -rf "$$X_DEBOOTSTRAP_DIR"; \
	mkdir -p "$$X_DEBOOTSTRAP_DIR"; \
	debootstrap_deb="$$(realpath "build/$$DISTRO-$$RELEASE/deb/debootstrap.deb")"; \
	cd "$$X_DEBOOTSTRAP_DIR"; \
	ar x "$$debootstrap_deb"; \
	tar xzf data.tar.*;
	[ -e "$@" ]
	touch "$@"

build/$(IMAGE_NAME)/root.fs/: \
  $(KERNEL_TARGET) \
  build/bin/usernsexec \
  $(DEBOOTSTRAP_SCRIPT) \
  bin/.dir \
  build/$(IMAGE_NAME)/.dir
	$(MAKE) extra_packages
	./script/debootstrap.sh

bin/$(IMAGE_NAME): \
  $(KERNEL_TARGET) \
  build/bin/fuseloop \
  build/$(IMAGE_NAME)/root.fs/ \
  $(PLATFORM_FILES)
	./script/assemble_image.sh

always:

.PHONY: always

rebuild: clean-fs clean-image always
	$(MAKE) all

clean-repo: clean-repo//fuseloop clean-repo//usernsexec
	$(MAKE) -C platform clean-repo
	$(MAKE) -C kernel clean-repo
	$(MAKE) -C chroot-build-helper clean-repo

update-repo: update-repo//fuseloop update-repo//usernsexec
	$(MAKE) -C platform update-repo
	$(MAKE) -C kernel update-repo
	if [ "$(BUILD_PACKAGES)" != no ]; \
	  then $(MAKE) -C chroot-build-helper update-repo; \
	fi

clean-build: clean-image clean-fs
	$(MAKE) -C platform clean-build
	$(MAKE) -C kernel clean-build
	$(MAKE) -C chroot-build-helper clean-build
	rm -rf build/bin/
	rmdir build/ 2>/dev/null || true

clean-build-all: clean-image-all clean-fs-all
	$(MAKE) -C platform clean-build-all
	$(MAKE) -C kernel clean-build-all
	$(MAKE) -C chroot-build-helper clean-build-all
	rm -rf build/

.SECONDEXPANSION:
repo: always \
  $$(call repodir,fuseloop) \
  $$(call repodir,usernsexec)
	$(MAKE) -C platform repo
	$(MAKE) -C kernel repo
	if [ "$(BUILD_PACKAGES)" != no ]; \
	  then $(MAKE) -C chroot-build-helper repo; \
	fi

build/bin/fuseloop: $$(call repodir,fuseloop) | build/bin/.dir
	with-repo.sh fuseloop bash -ex -c "\
	  $(MAKE) -C \"\$$repodir/fuseloop\"; \
	  cp \"\$$repodir/fuseloop/fuseloop\" build/bin/; \
	"

build/bin/usernsexec: $$(call repodir,usernsexec) | build/bin/.dir
	with-repo.sh usernsexec bash -ex -c "\
	  $(MAKE) -C \"\$$repodir/usernsexec/\"; \
	  cp \"\$$repodir/usernsexec/bin/usernsexec\" build/bin/; \
	  cp \"\$$repodir/usernsexec/script/uexec\" build/bin/; \
	"
