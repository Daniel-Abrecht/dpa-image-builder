
# TODO: get rid of this firmware crap, it's not FOSS!!!
repo/firmware-imx/.repo: repo/firmware-imx/.dir
	set -e; \
	file="repo/firmware-imx/firmware-imx-7.2.bin"; \
	wget https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-7.2.bin -O "$$file.tmp"; \
	if [ "$$(sha256sum "$$file".tmp | grep -o '^[^ ]*')" != 3e107d83ed2367c9565250d6ff3903cc604bf4d9aa505391260ead0f51ceb8d9 ]; then \
	  echo "Checksum mismatch, file firmware-imx-7.2.bin was modified by someone" >&2; \
	  false; \
	fi; \
	mv "$$file".tmp "$$file";
	touch "$@"
