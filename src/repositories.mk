
# TODO: get rid of this firmware crap, it's not FOSS!!!
repo/.firmware-imx.repo: repo/firmware-imx/.dir
	set -e; \
	file="repo/firmware-imx/firmware-imx-8.10.bin"; \
	wget https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-8.10.bin -O "$$file.tmp"; \
	if [ "$$(sha256sum "$$file".tmp | grep -o '^[^ ]*')" != 2b70f169d4065b2a7ac7a676afe24636128bd2dacc9f5230346758c3b146b2be ]; then \
	  echo "Checksum mismatch, file firmware-imx-8.10.bin was modified by someone" >&2; \
	  false; \
	fi; \
	mv "$$file".tmp "$$file";
	touch "$@"
