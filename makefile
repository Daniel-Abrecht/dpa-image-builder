IMGSIZE = 32GB # Note: 1GB = 1000MB, 1GiB=1024MiB 
RELEASE = ascii
REPO    = http://pkgmaster.devuan.org/merged/

all: bin/devuan-$(RELEASE)-imx8-base.img

bootloader: uboot/bin/uboot_firmware_and_dtb.bin
linux: kernel/bin/linux-image.deb

uboot/bin/uboot_firmware_and_dtb.bin:
	make -C uboot

kernel/bin/linux-image.deb:
	make -C kernel

%/.dir:
	mkdir -p "$(dir $@)"
	touch "$@"

build/fuseloop/.git: build/.dir
	git clone https://github.com/jmattsson/fuseloop.git build/fuseloop
	cd build/fuseloop && git reset --hard f2dfa371bbf457201de247c2b7bbb683694e0fb7

build/usernsexec/.git: build/.dir
	git clone https://github.com/Daniel-Abrecht/usernsexec.git build/usernsexec

build/tar2ext/.git: build/.dir
	git clone https://github.com/Daniel-Abrecht/tar2ext.git build/tar2ext

build/bin/fuseloop: build/fuseloop/.git build/bin/.dir
	make -C build/fuseloop/
	cp build/fuseloop/fuseloop build/bin/

build/bin/usernsexec: build/usernsexec/.git build/bin/.dir
	make -C build/usernsexec/
	cp build/usernsexec/bin/usernsexec build/bin/
	cp build/usernsexec/script/uexec build/bin/

build/bin/writeTar2Ext: build/tar2ext/.git build/bin/.dir
	make -C build/tar2ext/
	cp build/tar2ext/bin/writeTar2Ext build/bin/

build/filesystem/rootfs-$(RELEASE).tar: kernel/bin/linux-image.deb uboot/bin/uboot_firmware_and_dtb.bin build/bin/usernsexec include_packages include_packages_early rootfs_custom_files/ bin/.dir
	RELEASE="$(RELEASE)" REPO="$(REPO)" CHROOT_REPO="$(CHROOT_REPO)" ./script/debootstrap.sh

bin/devuan-$(RELEASE)-imx8-base.img: \
  build/bin/fuseloop \
  build/bin/writeTar2Ext \
  build/filesystem/rootfs-$(RELEASE).tar \
  uboot/bin/uboot_firmware_and_dtb.bin \
  kernel/bin/linux-image.deb
	IMGSIZE=$(IMGSIZE) RELEASE=$(RELEASE) ./script/assemble_image.sh

clean:
	make -C uboot clean
	make -C kernel clean
	rm -rf bin/ build/

emulate:
	qemu-system-aarch64 -M virt -cpu cortex-a53 -m 3G -kernel kernel/linux/debian/tmp/boot/vmlinuz-* -append "root=/dev/vda3" -drive if=none,file=bin/devuan-$(RELEASE)-imx8-base.img,format=raw,id=hd -device virtio-blk-device,drive=hd -nographic
