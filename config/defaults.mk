BOARD = devkit
IMGSIZE = 32GB # Note: 1GB = 1000MB, 1GiB=1024MiB 
RELEASE = ascii
REPO = http://pkgmaster.devuan.org/merged/
CHROOT_REPO = $(REPO)

IMAGE_NAME = devuan-$(RELEASE)-librem5-$(BOARD)-base.img

CROSS_COMPILER = aarch64-linux-gnu-

repo-branch@fuseloop = master
repo-source@fuseloop = https://github.com/jmattsson/fuseloop.git

repo-branch@usernsexec = master
repo-source@usernsexec = https://github.com/Daniel-Abrecht/usernsexec.git

repo-branch@tar2ext = master
repo-source@tar2ext = https://github.com/Daniel-Abrecht/tar2ext.git

repo-branch@Cortex_M4 = master
repo-source@Cortex_M4 = https://source.puri.sm/Librem5/Cortex_M4.git

repo-branch@arm-trusted-firmware = imx_4.9.51_imx8m_beta
repo-source@arm-trusted-firmware = https://source.codeaurora.org/external/imx/imx-atf

repo-branch@imx-mkimage = imx_4.9.51_imx8m_beta
repo-source@imx-mkimage = https://source.codeaurora.org/external/imx/imx-mkimage
