include ../../../src/make-helper-functions.mk

.SECONDEXPANSION:

UMAKE=env -u MAKEFLAGS CFLAGS="-Wno-error" LDFLAGS="-no-warn-rwx-segment" E=0 make

BOOTLOADER_COMPONENTS += bin/bl31.bin

all: bin/u-boot.bin
	@true

repo: \
  $$(call repodir,arm-trusted-firmware) \
  $$(call repodir,uboot)

bin/u-boot.bin: $$(call repodir,uboot) bin/bl31.elf | bin/.dir
	with-repo.sh uboot bash -ex -c '\
	  export BL31="$$(realpath bin/bl31.elf)"; \
	  $(UMAKE) -C "$$repodir/uboot/" ARCH=arm CROSS_COMPILE="$$CROSS_COMPILER" "$$UBOOT_CONFIG_TARGET"; \
	  $(UMAKE) -C "$$repodir/uboot/" ARCH=arm CROSS_COMPILE="$$CROSS_COMPILER"; \
	  cp "$$repodir/uboot/u-boot-rockchip.bin" "$@"; \
	'

bin/bl31.elf: $$(call repodir,arm-trusted-firmware) | bin/.dir
	with-repo.sh arm-trusted-firmware bash -ex -c '\
	  $(UMAKE) -C "$$repodir/arm-trusted-firmware/" PLAT="$$ATF_PLATFORM" CROSS_COMPILE="$$CROSS_COMPILER"; \
	  cp "$$repodir/arm-trusted-firmware/build/rk3399/release/bl31/bl31.elf" "$@"; \
	'

clean-repo: clean-repo//uboot clean-repo//arm-trusted-firmware
update-repo: update-repo//uboot update-repo//arm-trusted-firmware

clean-build-all: clean-build

clean-build:
	rm -rf bin repo/uboot/.built
