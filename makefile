include src/make-helper-functions.mk

all: bin/$(IMAGE_NAME)

bootloader: uboot/bin/uboot_firmware_and_dtb.bin
	@true

linux: kernel/bin/linux-image.deb
	@true

extra_packages:
	$(MAKE) -C chroot-build-helper

clean-fs-all:
	rm -rf build/filesystem

clean-fs:
	rm -rf "build/filesystem/bootfs-$(RELEASE).tar"
	rm -rf "build/filesystem/rootfs-$(RELEASE).tar"

clean-image-all:
	rm -f bin/*.img

clean-image:
	rm -f "bin/$(IMAGE_NAME)"

enter-buildenv:
	$(SETUPBUILDENV) "$(SHELL)"

uboot/bin/uboot_firmware_and_dtb.bin:
	$(MAKE) -C uboot

kernel/bin/linux-image.deb:
	$(MAKE) -C kernel

%/.dir:
	mkdir -p "$(dir $@)"
	touch "$@"

build/bin/fuseloop: repo/fuseloop/.repo build/bin/.dir
	$(MAKE) -C repo/fuseloop/
	cp repo/fuseloop/fuseloop build/bin/

build/bin/usernsexec: repo/usernsexec/.repo build/bin/.dir
	$(MAKE) -C repo/usernsexec/
	cp repo/usernsexec/bin/usernsexec build/bin/
	cp repo/usernsexec/script/uexec build/bin/

build/bin/writeTar2Ext: repo/tar2ext/.repo build/bin/.dir
	$(MAKE) -C repo/tar2ext/
	cp repo/tar2ext/bin/writeTar2Ext build/bin/

build/filesystem/rootfs-$(RELEASE).tar: \
  kernel/bin/linux-image.deb \
  uboot/bin/uboot_firmware_and_dtb.bin \
  build/bin/usernsexec \
  packages_install_debootstrap \
  packages_install_target \
  packages_download_only \
  rootfs_custom_files/ \
  bin/.dir
	$(MAKE) extra_packages
	./script/debootstrap.sh

bin/$(IMAGE_NAME): \
  build/bin/fuseloop \
  build/bin/writeTar2Ext \
  build/filesystem/rootfs-$(RELEASE).tar \
  uboot/bin/uboot_firmware_and_dtb.bin \
  kernel/bin/linux-image.deb
	./script/assemble_image.sh

uuu-do-%: script/uuu/%.lst
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

uuu-image-do-%: script/uuu/%.lst
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

repo: always \
  repo/fuseloop/.repo \
  repo/usernsexec/.repo \
  repo/tar2ext/.repo
	$(MAKE) -C uboot repo
	$(MAKE) -C kernel repo

clean-repo: clean-repo@fuseloop clean-repo@usernsexec clean-repo@tar2ext
	$(MAKE) -C uboot clean-repo
	$(MAKE) -C kernel clean-repo
	$(MAKE) -C chroot-build-helper clean-repo

reset-repo: reset-repo@fuseloop reset-repo@usernsexec reset-repo@tar2ext
	$(MAKE) -C uboot reset-repo
	$(MAKE) -C kernel reset-repo
	$(MAKE) -C chroot-build-helper reset-repo

clean-build:
	$(MAKE) -C uboot clean-build
	$(MAKE) -C kernel clean-build
	$(MAKE) -C chroot-build-helper clean-build
	rm -rf bin/ build/

emulate: bin/$(IMAGE_NAME) kernel/bin/linux-image.deb
	qemu-system-aarch64 -M virt -cpu cortex-a53 -m 3G -kernel repo/linux/debian/tmp/boot/vmlinuz-* -append "root=/dev/vda3" -drive if=none,file=bin/"$(IMAGE_NAME)",format=raw,id=hd -device virtio-blk-device,drive=hd -nographic
