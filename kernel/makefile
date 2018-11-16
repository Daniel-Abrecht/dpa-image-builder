all: bin/.done

linux/.git:
	git clone -b imx_4.9.51_imx8m_beta https://source.codeaurora.org/external/imx/linux-imx linux

linux/.config: linux/.git
	cp kernel_config linux/.config

bin/.done: linux/.git linux/.config
	make -C linux -j 9 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- deb-pkg
	mkdir -p bin
	cp linux-libc-*.deb bin/linux-libc.deb
	cp linux-image-*.deb bin/linux-image.deb
	cp linux-headers-*.deb bin/linux-headers.deb
	rm linux-*
	touch bin/.done

clean:
	rm -rf linux linux-* bin
