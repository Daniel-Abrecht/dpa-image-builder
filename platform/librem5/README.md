# Librem 5

## Boards

 * librem5-phone
 * librem5-devkit

## Flashing

For flashing the image, you'll also need uuu. You can get uuu from https://source.puri.sm/Librem5/mfgtools
Just make sure uuu is in your path when flashing the image. I've just copied the
built binaries to /usr/local: `cp uuu/uuu /usr/local/bin/; cp libuuu/libuuu* /usr/local/lib/;`

The uuu scripts this image builder uses are in `script/uuu/`.

## useful make targets

| Name | Purpose |
| ---- | ------- |
| uuu-flash | flash the image to emmc0 using uuu. You can specify a different image using IMAGE_NAME. If this image doesn't have an uboot usable for flashing, use IMAGE_UBOOT_UNFLASHABLE=1 to use the uboot from uboot/bin/uboot_firmware_and_dtb.bin instead for that step. |
| uuu-uboot-flash | flash uboot (doesn't include m4) |
| uuu-test-uboot | Just boot using uboot bootloader from uboot/bin/uboot_firmware_and_dtb.bin (doesn't quiet work as intended yet) |
| uuu-test-uboot@image | Just boot using uboot bootloader from bin/$(IMAGE_NAME). (doesn't quiet work as intended yet) |
| uuu-test-kernel | Just boot using kernel from .(kernel/bin/linux-image-*.deb. (doesn't quiet work as intended yet) |

## Other important stuff

There are currently 5 Proprietary binary blobs from nxp contained in the final uboot binary with non-free licenses:
 * `lpddr4_pmu_train_1d_dmem.bin`
 * `lpddr4_pmu_train_1d_imem.bin`
 * `lpddr4_pmu_train_2d_dmem.bin`
 * `lpddr4_pmu_train_2d_imem.bin`
 * `signed_hdmi_imx8m.bin`
 * `signed_dp_imx8m.bin`

One of the `lpddr4_*.bin` files is required for training the DDR PHY. The HDMI/DP bin file is for DRM HDMI/DP signals.
All of the `lpddr4_*.bin` firmware files are currently needed to build uboot and thus the image.
