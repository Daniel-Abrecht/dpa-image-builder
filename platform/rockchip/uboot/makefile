include ../../../src/make-helper-functions.mk

.SECONDEXPANSION:

UMAKE=env -u MAKEFLAGS make
#CFLAGS="-Wno-error" LDFLAGS="-no-warn-rwx-segment" E=0 make

BOOTLOADER_COMPONENTS += bin/$(BOARD)/bl31.elf
UBOOT_REPOS += $$(call repodir,arm-trusted-firmware)
UBOOT_REPOS += $$(call repodir,uboot)

ifeq ($(ATF_PLATFORM),rk3588)
# Unlike rk3399, rk3588 needs a TPL firmware to function
UBOOT_REPOS += $$(call repodir,rkbin)
export ROCKCHIP_TPL = $(shell realpath .)/bin/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.18.bin
BOOTLOADER_COMPONENTS += $(ROCKCHIP_TPL)
$(ROCKCHIP_TPL):
	with-repo.sh rkbin bash -ex -c 'cp "$$repodir/rkbin/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.18.bin" "$@"'
endif

all: bin/$(BOARD)/u-boot.bin
	@true

repo: $(UBOOT_REPOS)

bin/$(BOARD)/u-boot.bin: $$(call repodir,uboot) $(BOOTLOADER_COMPONENTS) | bin/$(BOARD)/.dir
	with-repo.sh uboot bash -ex -c '\
	  export BL31="$$(realpath bin/$(BOARD)/bl31.elf)"; \
	  $(UMAKE) -C "$$repodir/uboot/" ARCH=arm CROSS_COMPILE="$$CROSS_COMPILER" "$$UBOOT_CONFIG_TARGET"; \
	  $(UMAKE) -C "$$repodir/uboot/" ARCH=arm CROSS_COMPILE="$$CROSS_COMPILER"; \
	  cp "$$repodir/uboot/u-boot-rockchip.bin" "$@"; \
	'

bin/$(BOARD)/bl31.elf: $$(call repodir,arm-trusted-firmware) | bin/$(BOARD)/.dir
	with-repo.sh arm-trusted-firmware bash -ex -c '\
	  $(UMAKE) -C "$$repodir/arm-trusted-firmware/" PLAT="$$ATF_PLATFORM" CROSS_COMPILE="$$CROSS_COMPILER"; \
	  cp "$$repodir/arm-trusted-firmware/build/$$ATF_PLATFORM/release/bl31/bl31.elf" "$@"; \
	'

clean-repo: clean-repo//uboot clean-repo//arm-trusted-firmware
update-repo: update-repo//uboot update-repo//arm-trusted-firmware

clean-build-all: clean-build
	rm -rf bin

clean-build:
	rm -rf bin/$(BOARD)/ repo/uboot/.built
