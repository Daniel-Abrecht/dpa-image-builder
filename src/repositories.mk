
# TODO: get rid of this firmware crap, it's not FOSS!!!
repo/.firmware-imx.repo: repo/firmware-imx/.dir
	set -e; \
	file="repo/firmware-imx/firmware-imx-7.9.bin"; \
	wget https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-7.9.bin -O "$$file.tmp"; \
	if [ "$$(sha256sum "$$file".tmp | grep -o '^[^ ]*')" != 30e22c3e24a8025d60c52ed5a479e30fad3ad72127c84a870e69ec34e46ea8c0 ]; then \
	  echo "Checksum mismatch, file firmware-imx-7.9.bin was modified by someone" >&2; \
	  false; \
	fi; \
	mv "$$file".tmp "$$file";
	touch "$@"
