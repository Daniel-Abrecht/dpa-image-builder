
UBOOT_CONFIG_TARGET = imx8mq_evk_defconfig
UBOOT_DTB = fsl-imx8mq-evk.dtb

repo-branch@uboot = pureos-patches
repo-source@uboot = https://source.puri.sm/Librem5/uboot-imx.git

KERNEL_CONFIG_TARGET = imx8
KERNEL_DTB = freescale/fsl-imx8mq-evk-m4.dtb

repo-branch@linux = imx_4.9.51_imx8m_beta
repo-source@linux = https://source.codeaurora.org/external/imx/linux-imx

repo-branch@imx-mkimage = imx_4.9.51_imx8m_beta
repo-source@imx-mkimage = https://source.codeaurora.org/external/imx/imx-mkimage
