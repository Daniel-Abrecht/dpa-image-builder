ifdef KERNEL_CONFIG_TARGET
include ../src/make-helper-functions.mk

.SECONDEXPANSION:

all: bin/.done
	@true

menuconfig: $$(call repodir,linux)
	with-repo.sh linux bash -ex -c '\
	  if [ -f "configs/$$KERNEL_CONFIG_TARGET" ]; \
	    then cp "configs/$$KERNEL_CONFIG_TARGET" "$$repodir/linux/arch/arm64/configs/$${KERNEL_CONFIG_TARGET}_defconfig"; \
	  fi; \
	  $(MAKE) -C "$$repodir/linux" ARCH=arm64 CROSS_COMPILE="$$CROSS_COMPILER" "$$KERNEL_CONFIG_TARGET"_defconfig; \
	  $(MAKE) -C "$$repodir/linux" ARCH=arm64 CROSS_COMPILE="$$CROSS_COMPILER" menuconfig; \
	  $(MAKE) -C "$$repodir/linux" ARCH=arm64 CROSS_COMPILE="$$CROSS_COMPILER" savedefconfig; \
	  cp "$$repodir/linux/defconfig" "configs/$$KERNEL_CONFIG_TARGET"; \
	'

repo: $$(call repodir,linux)
	@true

bin/.done: $$(call repodir,linux) | bin/.dir
	with-repo.sh linux bash -ex -c '\
	  if [ -f "configs/$$KERNEL_CONFIG_TARGET" ]; \
	    then cp "configs/$$KERNEL_CONFIG_TARGET" "$$repodir/linux/arch/arm64/configs/$${KERNEL_CONFIG_TARGET}_defconfig"; \
	  fi; \
	  patchdir="$$(realpath "patch/$$BUILDER_PLATFORM/$$KERNEL_PATCHES" || true)"; \
	  if [ -n "$$KERNEL_PATCHES" ] && [ -d "$$patchdir" ]; \
	    then ( cd "$$repodir/linux"; for patch in "$$patchdir"/*.patch; do git apply "$$patch"; done ); \
	  fi; \
	  $(MAKE) -C "$$repodir/linux" ARCH=arm64 CROSS_COMPILE="$$CROSS_COMPILER" "$$KERNEL_CONFIG_TARGET"_defconfig; \
	  $(MAKE) -C "$$repodir/linux" ARCH=arm64 CROSS_COMPILE="$$CROSS_COMPILER" KBUILD_IMAGE=arch/arm64/boot/Image bindeb-pkg; \
	  cp "$$repodir"/linux-libc-*.deb bin/linux-libc.deb || true; \
	  cp "$$repodir"/linux-image-*[^g]_*_*.deb bin/linux-image.deb; \
	  cp "$$repodir"/linux-image-*g_*_*.deb bin/linux-image-dbg.deb || true; \
	  cp "$$repodir"/linux-headers-*.deb bin/linux-headers.deb || true; \
	'
	touch bin/.done;

clean-repo: clean-repo//linux
	@true

update-repo: update-repo//linux
	@true

clean-build-all: clean-build

clean-build:
	rm -rf bin
else
all:
	@true
%:
	@true
endif
