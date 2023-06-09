
# TODO: get rid of this firmware crap, it's not FOSS!!!
repo/.firmware-imx.repo: repo/firmware-imx/.dir
	set -e; \
	file="repo/firmware-imx/firmware-imx-8.12.bin"; \
	wget https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-8.12.bin -O "$$file.tmp"; \
	if [ "$$(sha256sum "$$file".tmp | grep -o '^[^ ]*')" != 6b6747bf36ecc53e385234afdce01f69c5775adf0d6685c885281ca6e4e322ef ]; then \
	  echo "Checksum mismatch, file firmware-imx-8.12.bin was modified by someone" >&2; \
	  false; \
	fi; \
	mv "$$file".tmp "$$file";
	touch "$@"
