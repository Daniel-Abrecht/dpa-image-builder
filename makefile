include src/make-helper-functions.mk

export X_DEBOOTSTRAP_DIR = $(project_root)/build/$(IMAGE_NAME)/debootstrap_script/
export DEBOOTSTRAP_SCRIPT = $(X_DEBOOTSTRAP_DIR)/usr/share/debootstrap/scripts/$(RELEASE)

all: bin/$(IMAGE_NAME)

linux: kernel/bin/linux-image.deb
	@true

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

build/bin/fuseloop: repo/.fuseloop.repo build/bin/.dir
	$(MAKE) -C repo/fuseloop/
	cp repo/fuseloop/fuseloop build/bin/

build/bin/usernsexec: repo/.usernsexec.repo build/bin/.dir
	$(MAKE) -C repo/usernsexec/
	cp repo/usernsexec/bin/usernsexec build/bin/
	cp repo/usernsexec/script/uexec build/bin/

build/bin/tar2ext: repo/.tar2ext.repo build/bin/.dir
	$(MAKE) -C repo/tar2ext/
	cp repo/tar2ext/scripts/sload.ext4 build/bin/
	( cd build/bin/; ln -sf sload.ext4 sload.ext3; ln -sf sload.ext4 sload.ext2; )
	cp repo/tar2ext/bin/tar2ext build/bin/

build/$(IMAGE_NAME)/deb/%.deb: build/$(IMAGE_NAME)/deb/.dir
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
  kernel/bin/linux-image.deb \
  build/bin/usernsexec \
  $(DEBOOTSTRAP_SCRIPT) \
  bin/.dir
	$(MAKE) extra_packages
	./script/debootstrap.sh

bin/$(IMAGE_NAME): \
  build/bin/fuseloop \
  build/bin/tar2ext \
  build/$(IMAGE_NAME)/root.fs/ \
  $(PLATFORM_FILES) \
  kernel/bin/linux-image.deb
	./script/assemble_image.sh

always:

.PHONY: always

rebuild: clean-fs clean-image always
	$(MAKE) all

repo: always \
  repo/.fuseloop.repo \
  repo/.usernsexec.repo \
  repo/.tar2ext.repo
	$(MAKE) -C uboot repo
	$(MAKE) -C kernel repo
	if [ "$(BUILD_PACKAGES)" != no ]; \
	  then $(MAKE) -C chroot-build-helper repo; \
	fi

clean-repo: clean-repo@fuseloop clean-repo@usernsexec clean-repo@tar2ext
	$(MAKE) -C uboot clean-repo
	$(MAKE) -C kernel clean-repo
	$(MAKE) -C chroot-build-helper clean-repo

reset-repo: reset-repo@fuseloop reset-repo@usernsexec reset-repo@tar2ext
	$(MAKE) -C uboot reset-repo
	$(MAKE) -C kernel reset-repo
	if [ "$(BUILD_PACKAGES)" != no ]; \
	  then $(MAKE) -C chroot-build-helper reset-repo; \
	fi

clean-build: clean-image clean-fs
	$(MAKE) -C uboot clean-build
	$(MAKE) -C kernel clean-build
	$(MAKE) -C chroot-build-helper clean-build
	rm -rf build/bin/
	rmdir build/ 2>/dev/null || true

clean-build-all: clean-image-all clean-fs-all
	$(MAKE) -C uboot clean-build
	$(MAKE) -C kernel clean-build
	$(MAKE) -C chroot-build-helper clean-build-all
	rm -rf build/

emulate: bin/$(IMAGE_NAME) kernel/bin/linux-image.deb
	qemu-system-aarch64 -M virt -cpu cortex-a53 -m 3G -kernel repo/linux/debian/tmp/boot/vmlinuz-* -append "root=/dev/vda3" -drive if=none,file=bin/"$(IMAGE_NAME)",format=raw,id=hd -device virtio-blk-device,drive=hd -nographic
