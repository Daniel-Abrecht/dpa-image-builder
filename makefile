include src/make-helper-functions.mk

export X_DEBOOTSTRAP_DIR = $(project_root)/build/$(IMAGE_NAME)/debootstrap_script/
export DEBOOTSTRAP_SCRIPT = $(X_DEBOOTSTRAP_DIR)/usr/share/debootstrap/scripts/$(RELEASE)

all: bin/$(IMAGE_NAME)

bootloader: uboot/bin/uboot_firmware_and_dtb.bin
	@true

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

uboot/bin/uboot_firmware_and_dtb.bin:
	$(MAKE) -C uboot

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

build/bin/writeTar2Ext: repo/.tar2ext.repo build/bin/.dir
	$(MAKE) -C repo/tar2ext/
	cp repo/tar2ext/bin/writeTar2Ext build/bin/

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

build/$(IMAGE_NAME)/rootfs.tar: \
  kernel/bin/linux-image.deb \
  uboot/bin/uboot_firmware_and_dtb.bin \
  build/bin/usernsexec \
  $(DEBOOTSTRAP_SCRIPT) \
  bin/.dir
	$(MAKE) extra_packages
	./script/debootstrap.sh

bin/$(IMAGE_NAME): \
  build/bin/fuseloop \
  build/bin/writeTar2Ext \
  build/$(IMAGE_NAME)/rootfs.tar \
  uboot/bin/uboot_firmware_and_dtb.bin \
  kernel/bin/linux-image.deb
	./script/assemble_image.sh

uuu-do-%: script/uuu/%.lst build/.dir
	# The sed stuff allows escaping $ using $$ in envsubst
	set -e; \
	export UBOOT_BIN; \
	tmplstfile="build/uuu-script.lst"; \
	cleanup(){ rm -f "$$tmplstfile"; }; \
	cleanup; \
	trap cleanup EXIT; \
	sed 's/\$$\$$/\x1/g' <"$<" | envsubst | sed 's/\x1/\$$/g' >"$$tmplstfile"; \
	uuu "$$tmplstfile";

uuu-uboot-do-%: script/uuu/%.lst uboot/bin/uboot_firmware_and_dtb.bin
	$(MAKE) UBOOT_BIN=uboot/bin/uboot_firmware_and_dtb.bin uuu-do-$(patsubst uuu-uboot-do-%,%,$@)

uuu-image-do-%: script/uuu/%.lst build/.dir
	# To determine the real size of the uboot binary is too complicated
	# instead, let's just assume 2MB are enough, its usually ~1M.
	# That's no problem for booting, just don't flash it.
	# A bigger size will fail to download, the offset wraps around...
	# (may be mitigateable by increasing the buffer size)
	set -e; \
        if [ "$(IMAGE_UBOOT_UNFLASHABLE)" = "1" ]; \
	then \
	  uboot="uboot/bin/uboot_firmware_and_dtb.bin"; \
	else \
	  uboot="build/extracted_uboot"; \
	  cleanup(){ rm -f "$$uboot"; }; \
	  cleanup; \
	  trap cleanup EXIT; \
	  dd if="bin/$(IMAGE_NAME)" of="$$uboot" bs=512 skip=66 count=4000; \
	fi; \
	$(MAKE) UBOOT_BIN="$$uboot" uuu-do-$(patsubst uuu-image-do-%,%,$@)

uuu-test-uboot: uuu-uboot-do-test-uboot
	@true

uuu-test-uboot@image: uuu-image-do-test-uboot
	@true

uuu-uboot-flash: uuu-uboot-do-uboot-flash
	@true

uuu-flash uuu-flash@image: uuu-image-do-flash
	@true

uuu-test-kernel: kernel/bin/linux-image.deb
	ar p kernel/bin/linux-image.deb data.tar.xz | tar xJ --wildcards './boot/vmlinuz-*' -O | gunzip > build/vmlinux
	ar p kernel/bin/linux-image.deb data.tar.xz | tar xJ --wildcards './usr/lib/linux-image-*/$(KERNEL_DTB)' -O > build/dtb
	$(MAKE) uuu-uboot-do-test-kernel || true
	rm build/vmlinux
	rm build/dtb

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
