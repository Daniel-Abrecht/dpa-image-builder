include ../src/make-helper-functions.mk

all: bin/.done
	@true

config: repo/linux/.config
	@true

menuconfig: repo/linux/.config
	$(MAKE) -C repo/linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILER) menuconfig
	$(MAKE) -C repo/linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILER) savedefconfig
	cp repo/linux/defconfig configs/$(KERNEL_CONFIG_TARGET)

repo: repo/.linux.repo
	@true

repo/linux/.config: repo/.linux.repo
	if [ -f "configs/$(KERNEL_CONFIG_TARGET)" ]; \
	  then cp "configs/$(KERNEL_CONFIG_TARGET)" "repo/linux/arch/arm64/configs/$(KERNEL_CONFIG_TARGET)_defconfig"; \
	fi
	$(MAKE) -C repo/linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILER) $(KERNEL_CONFIG_TARGET)_defconfig

bin/.done: repo/.linux.repo repo/linux/.config bin/.dir
	$(MAKE) -C repo/linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILER) bindeb-pkg
	cp repo/linux-libc-*.deb bin/linux-libc.deb || true
	cp repo/linux-image-*[^g]_*_*.deb bin/linux-image.deb
	cp repo/linux-image-*g_*_*.deb bin/linux-image-dbg.deb || true
	cp repo/linux-headers-*.deb bin/linux-headers.deb || true
	rm repo/linux-*
	touch bin/.done

clean-repo: clean-repo@linux
	@true

reset-repo: reset-repo@linux
	@true

clean-build-all: clean-build

clean-build:
	rm -rf bin
