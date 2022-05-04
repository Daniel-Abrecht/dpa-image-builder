include src/make-helper-functions.mk

all: bin/$(IMAGE_NAME)

ifdef KERNEL_CONFIG_TARGET
KERNEL_DEB=kernel/bin/linux-image.deb
endif

ifdef KERNEL_CONFIG_TARGET
linux: kernel/bin/linux-image.deb
	@true
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

enter-buildenv:
	export PROMPT_COMMAND='if [ -z "$$PS_SET" ]; then PS_SET=1; PS1="(buildenv) $$PS1"; fi'; \
	$(USER_SHELL)

kernel/bin/linux-image.deb:
	$(MAKE) -C kernel

%/.dir:
	mkdir -p "$(dir $@)"
	touch "$@"

build/$(IMAGE_NAME)/deb/%.deb: | build/$(IMAGE_NAME)/deb/.dir
	getdeb.sh "$@"

$(DEBOOTSTRAP_SCRIPT): build/$(IMAGE_NAME)/deb/debootstrap.deb
	set -e; \
	rm -rf "build/$(IMAGE_NAME)/debootstrap_script/"; \
	mkdir -p "build/$(IMAGE_NAME)/debootstrap_script/"; \
	cd "build/$(IMAGE_NAME)/debootstrap_script/"; \
	ar x ../deb/debootstrap.deb; \
	tar xzf data.tar.*;
	[ -e "$@" ]
	touch "$@"

build/$(IMAGE_NAME)/root.fs/: \
  $(KERNEL_DEB) \
  build/bin/usernsexec \
  $(DEBOOTSTRAP_SCRIPT) \
  bin/.dir
	$(MAKE) extra_packages
	./script/debootstrap.sh

bin/$(IMAGE_NAME): \
  $(KERNEL_DEB) \
  build/bin/fuseloop \
  build/bin/tar2ext \
  build/$(IMAGE_NAME)/root.fs/ \
  $(PLATFORM_FILES)
	./script/assemble_image.sh

always:

.PHONY: always

rebuild: clean-fs clean-image always
	$(MAKE) all

clean-repo: clean-repo//fuseloop clean-repo//usernsexec clean-repo//tar2ext
	$(MAKE) -C platform clean-repo
	$(MAKE) -C kernel clean-repo
	$(MAKE) -C chroot-build-helper clean-repo

update-repo: update-repo//fuseloop update-repo//usernsexec update-repo//tar2ext
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
	$(MAKE) -C platform clean-build
	$(MAKE) -C kernel clean-build
	$(MAKE) -C chroot-build-helper clean-build-all
	rm -rf build/

.SECONDEXPANSION:
repo: always \
  $$(call repodir,fuseloop) \
  $$(call repodir,usernsexec) \
  $$(call repodir,tar2ext)
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

build/bin/tar2ext: $$(call repodir,tar2ext) | build/bin/.dir
	with-repo.sh tar2ext bash -ex -c "\
	  $(MAKE) -C \"\$$repodir/tar2ext/\"; \
	  cp \"\$$repodir/tar2ext/scripts/sload.ext4\" build/bin/; \
	  cp \"\$$repodir/tar2ext/bin/tar2ext\" build/bin/; \
	"
	( cd build/bin/; ln -sf sload.ext4 sload.ext3; ln -sf sload.ext4 sload.ext2; )
