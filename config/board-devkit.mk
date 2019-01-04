
UBOOT_CONFIG_TARGET = librem5_devkit_base_defconfig
UBOOT_DTB = librem5-evk.dtb

repo-branch@uboot = devkit-wip
repo-source@uboot = https://source.puri.sm/DanielAbrecht/uboot-imx.git

KERNEL_CONFIG_TARGET = librem5-evk
KERNEL_DTB = freescale/librem5-evk-lcdonly.dtb

repo-branch@linux = imx8-4.18-wip
repo-source@linux = https://source.puri.sm/Librem5/linux-emcraft.git

repo-branch@imx-mkimage = imx-mkimage-emcraft
repo-source@imx-mkimage = ../../.git
