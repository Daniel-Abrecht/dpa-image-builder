
# TODO: get rid of this firmware crap, it's not FOSS!!!
repo/.firmware-imx.repo: repo/firmware-imx/.dir
	set -e; \
	file="repo/firmware-imx/firmware-imx-8.7.bin"; \
	wget https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-8.7.bin -O "$$file.tmp"; \
	if [ "$$(sha256sum "$$file".tmp | grep -o '^[^ ]*')" != 92c1713f61a99b1ff5046a795789e6021db1e8bb5534c02e4b719f1436e15615 ]; then \
	  echo "Checksum mismatch, file firmware-imx-8.7.bin was modified by someone" >&2; \
	  false; \
	fi; \
	mv "$$file".tmp "$$file";
	touch "$@"
