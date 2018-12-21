include ../src/make-helper-functions.mk

BOOTLOADER_COMPONENTS += dtb/$(UBOOT_DTB)
BOOTLOADER_COMPONENTS += firmware/u-boot-nodtb.bin
BOOTLOADER_COMPONENTS += firmware/u-boot-spl.bin
BOOTLOADER_COMPONENTS += firmware/m4.bin
BOOTLOADER_COMPONENTS += firmware/bl31.bin
BOOTLOADER_COMPONENTS += bin/mkimage_uboot

# TODO: get rid of the following non-free files
NONFREE_FIRMWARE_CRAP += firmware/lpddr4_pmu_train_1d_dmem.bin
NONFREE_FIRMWARE_CRAP += firmware/lpddr4_pmu_train_1d_imem.bin
NONFREE_FIRMWARE_CRAP += firmware/lpddr4_pmu_train_2d_dmem.bin
NONFREE_FIRMWARE_CRAP += firmware/lpddr4_pmu_train_2d_imem.bin
NONFREE_FIRMWARE_CRAP += firmware/signed_hdmi_imx8m.bin

BOOTLOADER_COMPONENTS += $(NONFREE_FIRMWARE_CRAP)

all: bin/uboot_firmware_and_dtb.bin

repo: \
  repo/Cortex_M4/.repo \
  repo/arm-trusted-firmware/.repo \
  repo/firmware-imx/.repo

repo/uboot/.built: repo/uboot/.repo dtb/.dir bin/.dir firmware/.dir
	$(MAKE) -C "repo/uboot" ARCH=arm CROSS_COMPILE=$(CROSS_COMPILER) $(UBOOT_CONFIG_TARGET)
	$(MAKE) -C "repo/uboot" ARCH=arm CROSS_COMPILE=$(CROSS_COMPILER)
	cp "repo/uboot/u-boot-nodtb.bin" "firmware/"
	cp "repo/uboot/spl/u-boot-spl.bin" "firmware/"
	cp "repo/uboot/tools/mkimage" "bin/mkimage_uboot"
	cp "repo/uboot/arch/arm/dts/"*.dtb "dtb/"
	rm -f "mkimage_imx8"
	touch repo/uboot/.built

dtb/%.dtb: repo/uboot/.built
	true

firmware/u-boot-nodtb.bin firmware/u-boot-spl.bin bin/mkimage_uboot: repo/uboot/.built
	true

firmware/m4.bin: repo/Cortex_M4/.repo firmware/.dir
	$(MAKE) -C "repo/Cortex_M4/"
	cp "repo/Cortex_M4/m4.bin" "firmware"

firmware/bl31.bin: repo/arm-trusted-firmware/.repo firmware/.dir
	$(MAKE) -C "repo/arm-trusted-firmware/" PLAT=imx8mq CROSS_COMPILE=$(CROSS_COMPILER) bl31
	cp "repo/arm-trusted-firmware/build/imx8mq/release/bl31.bin" "firmware/"

$(NONFREE_FIRMWARE_CRAP): repo/firmware-imx/.repo
	tail -n +712 repo/firmware-imx/firmware-imx-*.bin | ( cd "repo/firmware-imx/" <&- && tar xjvf -; )
	cp "repo"/firmware-imx/firmware-imx-7.2/firmware/ddr/synopsys/lpddr4_pmu_train_1d_dmem.bin "firmware/"
	cp "repo"/firmware-imx/firmware-imx-7.2/firmware/ddr/synopsys/lpddr4_pmu_train_1d_imem.bin "firmware/"
	cp "repo"/firmware-imx/firmware-imx-7.2/firmware/ddr/synopsys/lpddr4_pmu_train_2d_dmem.bin "firmware/"
	cp "repo"/firmware-imx/firmware-imx-7.2/firmware/ddr/synopsys/lpddr4_pmu_train_2d_imem.bin "firmware/"
	cp "repo"/firmware-imx/firmware-imx-7.2/firmware/hdmi/cadence/signed_hdmi_imx8m.bin "firmware/"

# TODO: Put dtb and firmware on a partition and change boot loader percedure
bin/uboot_firmware_and_dtb.bin: $(BOOTLOADER_COMPONENTS) | repo/imx-mkimage/.repo
	cp $^ "repo"/imx-mkimage/iMX8M/
	$(MAKE) -C "repo"/imx-mkimage/ SOC=iMX8M flash_hdmi_spl_uboot
	cp "repo/imx-mkimage/iMX8M/flash.bin" "bin/uboot_firmware_and_dtb.bin"

clean-repo: clean-repo@uboot clean-repo@Cortex_M4 clean-repo@arm-trusted-firmware clean-repo@imx-mkimage clean-repo@firmware-imx
reset-repo: reset-repo@uboot reset-repo@Cortex_M4 reset-repo@arm-trusted-firmware reset-repo@imx-mkimage

clean-build:
	rm -rf "firmware" "dtb" "bin" repo/uboot/.built
