include ../../../src/make-helper-functions.mk

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

config: repo/uboot/.config
	@true

repo: \
  repo/.Cortex_M4.repo \
  repo/.arm-trusted-firmware.repo \
  repo/.firmware-imx.repo

repo/uboot/.config: repo/.uboot.repo
	$(UMAKE) -C repo/uboot ARCH=arm CROSS_COMPILE=$(CROSS_COMPILER) $(UBOOT_CONFIG_TARGET)

bin/uboot_firmware_and_dtb.bin: repo/.uboot.repo repo/uboot/.config bin/.dir $(BOOTLOADER_COMPONENTS)
	cp $(BOOTLOADER_COMPONENTS) repo/uboot/
	$(UMAKE) -C repo/uboot ARCH=arm CROSS_COMPILE=$(CROSS_COMPILER) flash.bin
	$(UMAKE) -C repo/uboot ARCH=arm CROSS_COMPILE=$(CROSS_COMPILER) u-boot.imx
	cp repo/uboot/u-boot.imx "$@"

firmware/m4.bin: repo/.Cortex_M4.repo firmware/.dir
	$(UMAKE) -C repo/Cortex_M4/
	cp repo/Cortex_M4/m4.bin firmware/

firmware/bl31.bin: repo/.arm-trusted-firmware.repo firmware/.dir
	$(UMAKE) -C repo/arm-trusted-firmware/ PLAT=$(ATF_PLATFORM) CROSS_COMPILE=$(CROSS_COMPILER) bl31
	cp repo/arm-trusted-firmware/build/imx8mq/release/bl31.bin firmware/

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

clean-repo: clean-repo@uboot clean-repo@Cortex_M4 clean-repo@arm-trusted-firmware clean-repo@firmware-imx
reset-repo: reset-repo@uboot reset-repo@Cortex_M4 reset-repo@arm-trusted-firmware

clean-build-all: clean-build

clean-build:
	rm -rf firmware bin repo/uboot/.built
