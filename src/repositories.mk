
repo/fuseloop/.repo: build/.dir
	git clone https://github.com/jmattsson/fuseloop.git repo/fuseloop
	touch "$@"

repo/usernsexec/.repo: build/.dir
	git clone https://github.com/Daniel-Abrecht/usernsexec.git repo/usernsexec
	touch "$@"

repo/tar2ext/.repo: build/.dir
	git clone https://github.com/Daniel-Abrecht/tar2ext.git repo/tar2ext
	touch "$@"

repo/uboot-imx/.repo: repo/.dir
	git clone -b pureos-patches https://source.puri.sm/Librem5/uboot-imx.git "repo/uboot-imx/"
	touch "$@"

repo/Cortex_M4/.repo: repo/.dir
	#git clone git@code.puri.sm:Angus_Ainslie/Cortex_M4.git # That was probably an internal repo
	git clone https://source.puri.sm/Librem5/Cortex_M4.git "repo/Cortex_M4/"
	touch "$@"

repo/arm-trusted-firmware/.repo: repo/.dir
	#git clone https://github.com/ARM-software/arm-trusted-firmware.git # TODO: Check this out from master once imx8mq gets merged.
	git clone -b imx_4.9.51_imx8m_beta https://source.codeaurora.org/external/imx/imx-atf "repo/arm-trusted-firmware/"
	touch "$@"

repo/imx-mkimage/.repo: repo/.dir
	git clone https://source.codeaurora.org/external/imx/imx-mkimage -b imx_4.9.51_imx8m_beta "repo/imx-mkimage/"
	touch "$@"

# TODO: get this to work with mainline
repo/linux/.repo:
	git clone -b imx_4.9.51_imx8m_beta https://source.codeaurora.org/external/imx/linux-imx repo/linux
	touch "$@"

# TODO: get rid of this firmware crap, it's not FOSS!!!
repo/firmware-imx/.repo: repo/firmware-imx/.dir
	wget https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-7.2.bin -O "$@".tmp
	if [ "$$(sha256sum "$@".tmp | grep -o '^[^ ]*')" != 3e107d83ed2367c9565250d6ff3903cc604bf4d9aa505391260ead0f51ceb8d9 ]; then \
	  echo "Checksum mismatch, file firmware-imx-7.2.bin was modified by someone" >&2; \
	  false; \
	fi
	mv "$@".tmp "$@"
	touch "$@"
