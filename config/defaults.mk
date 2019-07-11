BOARD = devkit
IMGSIZE = 3GiB # Note: 1GB = 1000MB, 1GiB=1024MiB 
DISTRO = devuan
RELEASE = $(DEFAULT_RELEASE-$(DISTRO))
VARIANT = base
REPO = http://pkgmaster.devuan.org/merged/
CHROOT_REPO = $(REPO)

REPO-devuan = http://pkgmaster.devuan.org/merged/
REPO-debian = http://deb.debian.org/debian/
REPO-ubuntu = http://ports.ubuntu.com/ubuntu-ports/

DEFAULT_RELEASE-devuan = beowulf
DEFAULT_RELEASE-debian = buster
DEFAULT_RELEASE-ubuntu = disco

IMAGE_NAME = $(DISTRO)-$(RELEASE)-librem5-$(BOARD)-$(VARIANT).img

CROSS_COMPILER = aarch64-linux-gnu-

repo-branch@fuseloop = master
repo-source@fuseloop = https://github.com/jmattsson/fuseloop.git

repo-branch@usernsexec = master
repo-source@usernsexec = https://github.com/Daniel-Abrecht/usernsexec.git

repo-branch@tar2ext = master
repo-source@tar2ext = https://github.com/Daniel-Abrecht/tar2ext.git

repo-branch@Cortex_M4 = master
repo-source@Cortex_M4 = https://source.puri.sm/Librem5/Cortex_M4.git

ATF_PLATFORM = imx8mq
repo-branch@arm-trusted-firmware = librem5
repo-source@arm-trusted-firmware = https://source.puri.sm/Librem5/trusted-firmware-a
