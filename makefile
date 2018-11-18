IMGSIZE = 32GB # Note: 1GB = 1000MB, 1GiB=1024MiB 
RELEASE = ascii
REPO    = http://pkgmaster.devuan.org/merged/
IMAGE_NAME = devuan-$(RELEASE)-librem5-devkit-base.img

all: bin/$(IMAGE_NAME)

include src/make-helper-functions.mk

bootloader: uboot/bin/uboot_firmware_and_dtb.bin
linux: kernel/bin/linux-image.deb

clean-fs-all:
	rm -rf build/filesystem

clean-fs:
	rm -rf "build/filesystem/bootfs-$(RELEASE).tar"
	rm -rf "build/filesystem/rootfs-$(RELEASE).tar"

clean-image-all:
	rm -f bin/*.img

clean-image:
	rm -f "bin/$(IMAGE_NAME)"

uboot/bin/uboot_firmware_and_dtb.bin:
	make -C uboot

kernel/bin/linux-image.deb:
	make -C kernel

%/.dir:
	mkdir -p "$(dir $@)"
	touch "$@"

build/bin/fuseloop: repo/fuseloop/.repo build/bin/.dir
	make -C repo/fuseloop/
	cp repo/fuseloop/fuseloop build/bin/

build/bin/usernsexec: repo/usernsexec/.repo build/bin/.dir
	make -C repo/usernsexec/
	cp repo/usernsexec/bin/usernsexec build/bin/
	cp repo/usernsexec/script/uexec build/bin/

build/bin/writeTar2Ext: repo/tar2ext/.repo build/bin/.dir
	make -C repo/tar2ext/
	cp repo/tar2ext/bin/writeTar2Ext build/bin/

build/filesystem/rootfs-$(RELEASE).tar: kernel/bin/linux-image.deb uboot/bin/uboot_firmware_and_dtb.bin build/bin/usernsexec include_packages include_packages_early rootfs_custom_files/ bin/.dir
	RELEASE="$(RELEASE)" REPO="$(REPO)" CHROOT_REPO="$(CHROOT_REPO)" ./script/debootstrap.sh

bin/$(IMAGE_NAME): \
  build/bin/fuseloop \
  build/bin/writeTar2Ext \
  build/filesystem/rootfs-$(RELEASE).tar \
  uboot/bin/uboot_firmware_and_dtb.bin \
  kernel/bin/linux-image.deb
	IMGSIZE=$(IMGSIZE) RELEASE=$(RELEASE) IMAGE_NAME=$(IMAGE_NAME) ./script/assemble_image.sh

always:

repo: always \
  repo/fuseloop/.repo \
  repo/usernsexec/.repo \
  repo/tar2ext/.repo
	make -C uboot repo
	make -C kernel repo

clean-repo: clean-repo@fuseloop clean-repo@usernsexec clean-repo@tar2ext
	make -C uboot clean-repo
	make -C kernel clean-repo

reset-repo: reset-repo@fuseloop reset-repo@usernsexec reset-repo@tar2ext
	make -C uboot reset-repo
	make -C kernel reset-repo

clean-build:
	make -C uboot clean-build
	make -C kernel clean-build
	rm -rf bin/ build/

emulate: bin/$(IMAGE_NAME) kernel/bin/linux-image.deb
	qemu-system-aarch64 -M virt -cpu cortex-a53 -m 3G -kernel repo/linux/debian/tmp/boot/vmlinuz-* -append "root=/dev/vda3" -drive if=none,file=bin/$(IMAGE_NAME),format=raw,id=hd -device virtio-blk-device,drive=hd -nographic
