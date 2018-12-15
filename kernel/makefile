include ../src/make-helper-functions.mk

all: bin/.done

repo: repo/linux/.repo

repo/linux/.config: repo/linux/.repo
	cp kernel_config repo/linux/.config

bin/.done: repo/linux/.repo repo/linux/.config bin/.dir
	$(MAKE) -C repo/linux ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- deb-pkg
	cp repo/linux-libc-*.deb bin/linux-libc.deb
	cp repo/linux-image-*.deb bin/linux-image.deb
	cp repo/linux-headers-*.deb bin/linux-headers.deb
	rm repo/linux-*
	touch bin/.done

clean-repo: clean-repo@linux
reset-repo: reset-repo@linux

clean-build:
	rm -rf bin
