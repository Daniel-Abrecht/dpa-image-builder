include ../../../src/make-helper-functions.mk

UMAKE=env -u MAKEFLAGS make

BOOTLOADER_COMPONENTS += bin/bl31.bin

all: bin/u-boot.bin
	@true

config: repo/uboot/.config
	@true

repo: repo/.arm-trusted-firmware.repo repo/.uboot.repo

repo/uboot/.config: repo/.uboot.repo
	$(UMAKE) -C repo/uboot ARCH=arm CROSS_COMPILE=$(CROSS_COMPILER) $(UBOOT_CONFIG_TARGET)

bin/u-boot.bin: repo/.uboot.repo repo/uboot/.config bin/.dir bin/bl31.elf
	cp bin/bl31.elf repo/uboot/
	$(UMAKE) -C repo/uboot ARCH=arm CROSS_COMPILE=$(CROSS_COMPILER)
	cp repo/uboot/u-boot-rockchip.bin $@

bin/bl31.elf: repo/.arm-trusted-firmware.repo
	$(UMAKE) -C repo/arm-trusted-firmware/ PLAT=$(ATF_PLATFORM) CROSS_COMPILE=$(CROSS_COMPILER)
	cp repo/arm-trusted-firmware/build/rk3399/release/bl31/bl31.elf bin/

clean-repo: clean-repo@uboot clean-repo@arm-trusted-firmware
reset-repo: reset-repo@uboot reset-repo@arm-trusted-firmware

clean-build-all: clean-build

clean-build:
	rm -rf bin repo/uboot/.built
