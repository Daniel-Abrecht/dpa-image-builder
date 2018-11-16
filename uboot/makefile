fwdir=firmware
dtbdir=dtb
bindir=bin
repodir=repo

BOOTLOADER_COMPONENTS += $(dtbdir)/fsl-imx8mq-evk.dtb
BOOTLOADER_COMPONENTS += $(fwdir)/u-boot-nodtb.bin
BOOTLOADER_COMPONENTS += $(fwdir)/u-boot-spl.bin
BOOTLOADER_COMPONENTS += $(fwdir)/m4.bin
BOOTLOADER_COMPONENTS += $(fwdir)/bl31.bin
BOOTLOADER_COMPONENTS += $(bindir)/mkimage_uboot

# TODO: get rid of the following non-free files
NONFREE_FIRMWARE_CRAP += $(fwdir)/lpddr4_pmu_train_1d_dmem.bin
NONFREE_FIRMWARE_CRAP += $(fwdir)/lpddr4_pmu_train_1d_imem.bin
NONFREE_FIRMWARE_CRAP += $(fwdir)/lpddr4_pmu_train_2d_dmem.bin
NONFREE_FIRMWARE_CRAP += $(fwdir)/lpddr4_pmu_train_2d_imem.bin
NONFREE_FIRMWARE_CRAP += $(fwdir)/signed_hdmi_imx8m.bin

BOOTLOADER_COMPONENTS += $(NONFREE_FIRMWARE_CRAP)

all: $(bindir)/uboot_firmware_and_dtb.bin

%/.dir: # We don't care if the directory gets modified, only if it exists or not. Let's check a dummy file instead
	mkdir -p "$(dir $@)"
	touch "$@"

$(repodir)/uboot-imx/.repo: $(repodir)/.dir
	git clone -b pureos-patches https://source.puri.sm/Librem5/uboot-imx.git "$(repodir)/uboot-imx/"
	touch "$@"

$(repodir)/Cortex_M4/.repo: $(repodir)/.dir
	#git clone git@code.puri.sm:Angus_Ainslie/Cortex_M4.git # That was probably an internal repo
	git clone https://source.puri.sm/Librem5/Cortex_M4.git "$(repodir)/Cortex_M4/"
	touch "$@"

$(repodir)/arm-trusted-firmware/.repo: $(repodir)/.dir
	#git clone https://github.com/ARM-software/arm-trusted-firmware.git # TODO: Check this out from master once imx8mq gets merged.
	git clone -b imx_4.9.51_imx8m_beta https://source.codeaurora.org/external/imx/imx-atf "$(repodir)/arm-trusted-firmware/"
	touch "$@"

$(repodir)/imx-mkimage/.repo: $(repodir)/.dir
	git clone https://source.codeaurora.org/external/imx/imx-mkimage -b imx_4.9.51_imx8m_beta "$(repodir)/imx-mkimage/"
	touch "$@"

$(dtbdir)/fsl-imx8mq-evk.dtb $(fwdir)/u-boot-nodtb.bin $(fwdir)/u-boot-spl.bin $(bindir)/mkimage_uboot: $(repodir)/uboot-imx/.repo $(dtbdir)/.dir $(bindir)/.dir $(fwdir)/.dir
	make -C "$(repodir)/uboot-imx" ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- imx8mq_evk_defconfig
	make -C "$(repodir)/uboot-imx" ARCH=arm CROSS_COMPILE=aarch64-linux-gnu-
	cp "$(repodir)/uboot-imx/u-boot-nodtb.bin" "$(fwdir)/"
	cp "$(repodir)/uboot-imx/spl/u-boot-spl.bin" "$(fwdir)/"
	cp "$(repodir)/uboot-imx/arch/arm/dts/fsl-imx8mq-evk.dtb" "$(dtbdir)/"
	cp "$(repodir)/uboot-imx/tools/mkimage" "$(bindir)/mkimage_uboot"

$(fwdir)/m4.bin: $(repodir)/Cortex_M4/.repo $(fwdir)/.dir
	make -C "$(repodir)/Cortex_M4/"
	cp "$(repodir)/Cortex_M4/m4.bin" "$(fwdir)"


$(fwdir)/bl31.bin: $(repodir)/arm-trusted-firmware/.repo $(fwdir)/.dir
	make -C "$(repodir)/arm-trusted-firmware/" PLAT=imx8mq CROSS_COMPILE=aarch64-linux-gnu- bl31
	cp "$(repodir)/arm-trusted-firmware/build/imx8mq/release/bl31.bin" "$(fwdir)/"

# TODO: get rid of this crap, it's not FOSS!!!
$(repodir)/firmware-imx/firmware-imx-7.2.bin: $(repodir)/firmware-imx/.dir
	wget https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-7.2.bin -O "$@".tmp
	if [ "$$(sha256sum "$@".tmp | grep -o '^[^ ]*')" != 3e107d83ed2367c9565250d6ff3903cc604bf4d9aa505391260ead0f51ceb8d9 ]; then \
	  echo "Checksum mismatch, file firmware-imx-7.2.bin was modified by someone" >&2; \
	  false; \
	fi
	mv "$@".tmp "$@"

$(NONFREE_FIRMWARE_CRAP): $(repodir)/firmware-imx/firmware-imx-7.2.bin
	tail -n +712 "$^" | ( cd "$(repodir)/firmware-imx/" <&- && tar xjvf -; )
	cp "$(repodir)"/firmware-imx/firmware-imx-7.2/firmware/ddr/synopsys/lpddr4_pmu_train_1d_dmem.bin "$(fwdir)/"
	cp "$(repodir)"/firmware-imx/firmware-imx-7.2/firmware/ddr/synopsys/lpddr4_pmu_train_1d_imem.bin "$(fwdir)/"
	cp "$(repodir)"/firmware-imx/firmware-imx-7.2/firmware/ddr/synopsys/lpddr4_pmu_train_2d_dmem.bin "$(fwdir)/"
	cp "$(repodir)"/firmware-imx/firmware-imx-7.2/firmware/ddr/synopsys/lpddr4_pmu_train_2d_imem.bin "$(fwdir)/"
	cp "$(repodir)"/firmware-imx/firmware-imx-7.2/firmware/hdmi/cadence/signed_hdmi_imx8m.bin "$(fwdir)/"

# TODO: Put dtb and firmware on a partition and change boot loader percedure
$(bindir)/uboot_firmware_and_dtb.bin: $(repodir)/imx-mkimage/.repo $(BOOTLOADER_COMPONENTS) 
	cp $^ "$(repodir)"/imx-mkimage/iMX8M/
	make -C "$(repodir)"/imx-mkimage/ SOC=iMX8M flash_hdmi_spl_uboot
	cp "$(repodir)/imx-mkimage/iMX8M/flash.bin" "$(bindir)/uboot_firmware_and_dtb.bin"

clean:
	rm -rf "$(repodir)" "$(fwdir)" "$(dtbdir)" "$(bindir)"
