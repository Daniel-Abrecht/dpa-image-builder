include ../../../src/make-helper-functions.mk

.SECONDEXPANSION:

UMAKE=env -u MAKEFLAGS make

BOOTLOADER_COMPONENTS += firmware/m4.bin
BOOTLOADER_COMPONENTS += firmware/bl31.bin

# TODO: get rid of the following non-free files
NONFREE_FIRMWARE_CRAP += firmware/lpddr4_pmu_train_1d_dmem.bin
NONFREE_FIRMWARE_CRAP += firmware/lpddr4_pmu_train_1d_imem.bin
NONFREE_FIRMWARE_CRAP += firmware/lpddr4_pmu_train_2d_dmem.bin
NONFREE_FIRMWARE_CRAP += firmware/lpddr4_pmu_train_2d_imem.bin
NONFREE_FIRMWARE_CRAP += firmware/signed_hdmi_imx8m.bin
NONFREE_FIRMWARE_CRAP += firmware/signed_dp_imx8m.bin

BOOTLOADER_COMPONENTS += $(NONFREE_FIRMWARE_CRAP)

all: bin/uboot_firmware_and_dtb.bin
	@true

repo: \
  repo/.firmware-imx.repo \
  $$(call repodir,Cortex_M4) \
  $$(call repodir,arm-trusted-firmware) \
  $$(call repodir,uboot)

bin/uboot_firmware_and_dtb.bin: $$(call repodir,uboot) $(BOOTLOADER_COMPONENTS) | bin/.dir
	with-repo.sh uboot bash -ex -c '\
	  cp $(BOOTLOADER_COMPONENTS) "$$repodir/uboot/"; \
	  $(UMAKE) -C "$$repodir/uboot/" ARCH=arm CROSS_COMPILE="$$CROSS_COMPILER" "$$UBOOT_CONFIG_TARGET"; \
	  $(UMAKE) -C "$$repodir/uboot/" ARCH=arm CROSS_COMPILE="$$CROSS_COMPILER" flash.bin; \
	  $(UMAKE) -C "$$repodir/uboot/" ARCH=arm CROSS_COMPILE="$$CROSS_COMPILER" u-boot.imx; \
	  cp "$$repodir/uboot/u-boot.imx" "$@"; \
	'

firmware/m4.bin: $$(call repodir,Cortex_M4) | firmware/.dir
	with-repo.sh Cortex_M4 bash -ex -c '\
	  $(UMAKE) -C "$$repodir/Cortex_M4/"; \
	  cp "$$repodir/Cortex_M4/m4.bin" "$@"; \
	'

firmware/bl31.bin: $$(call repodir,arm-trusted-firmware) | bin/.dir
	with-repo.sh arm-trusted-firmware bash -ex -c '\
	  $(UMAKE) -C "$$repodir/arm-trusted-firmware/" PLAT="$$ATF_PLATFORM" CROSS_COMPILE="$$CROSS_COMPILER" bl31; \
	  cp "$$repodir/arm-trusted-firmware/build/imx8mq/release/bl31.bin" "$@"; \
	'

firmware/.fw: repo/.firmware-imx.repo
	fwbin=$(wildcard repo/firmware-imx/firmware-imx-*.bin); \
	fwstart="$$(expr "$$(grep -an '^exit 0' "$$fwbin" | head -n 1 | grep -o '^[0-9]*')" + 1)"; \
	tail -n +"$$fwstart" "$$fwbin" | ( cd "repo/firmware-imx/" <&- && tar xjvf -; )
	cp repo/firmware-imx/firmware-imx-*/firmware/ddr/synopsys/lpddr4_pmu_train_1d_dmem.bin firmware/
	cp repo/firmware-imx/firmware-imx-*/firmware/ddr/synopsys/lpddr4_pmu_train_1d_imem.bin firmware/
	cp repo/firmware-imx/firmware-imx-*/firmware/ddr/synopsys/lpddr4_pmu_train_2d_dmem.bin firmware/
	cp repo/firmware-imx/firmware-imx-*/firmware/ddr/synopsys/lpddr4_pmu_train_2d_imem.bin firmware/
	cp repo/firmware-imx/firmware-imx-*/firmware/hdmi/cadence/signed_hdmi_imx8m.bin firmware/
	cp repo/firmware-imx/firmware-imx-*/firmware/hdmi/cadence/signed_dp_imx8m.bin firmware/
	touch $@

$(NONFREE_FIRMWARE_CRAP): firmware/.fw
	true

clean-repo: clean-repo//uboot clean-repo//arm-trusted-firmware
update-repo: update-repo//uboot update-repo//arm-trusted-firmware

clean-build-all: clean-build

clean-build:
	rm -rf firmware bin
