include ../src/make-helper-functions.mk
ifdef KERNEL_CONFIG_TARGET

.SECONDEXPANSION:

all: bin/$(KERNEL_CONFIG_TARGET)/.done
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

bin/$(KERNEL_CONFIG_TARGET)/.done: $$(call repodir,linux) | bin/$(KERNEL_CONFIG_TARGET)/.dir
	with-repo.sh linux bash -ex -c '\
	  if [ -f "configs/$$KERNEL_CONFIG_TARGET" ]; \
	    then cp "configs/$$KERNEL_CONFIG_TARGET" "$$repodir/linux/arch/arm64/configs/$${KERNEL_CONFIG_TARGET}_defconfig"; \
	  fi; \
	  patchdir="$$(realpath "patch/$$KERNEL_CONFIG_TARGET/$$KERNEL_PATCHES" || true)"; \
	  if [ -n "$$KERNEL_PATCHES" ] && [ -d "$$patchdir" ]; \
	    then ( cd "$$repodir/linux"; for patch in "$$patchdir"/*.patch; do git apply "$$patch"; done ); \
	  fi; \
	  $(MAKE) -C "$$repodir/linux" ARCH=arm64 CROSS_COMPILE="$$CROSS_COMPILER" "$$KERNEL_CONFIG_TARGET"_defconfig; \
	  $(MAKE) -C "$$repodir/linux" ARCH=arm64 CROSS_COMPILE="$$CROSS_COMPILER" KBUILD_IMAGE=arch/arm64/boot/Image bindeb-pkg; \
	  cp "$$repodir"/linux-*.deb "bin/$$KERNEL_CONFIG_TARGET/"; \
	'
	touch "bin/$$KERNEL_CONFIG_TARGET/.done";

clean-repo: clean-repo//linux
	@true

update-repo: update-repo//linux
	@true

clean-build-all: clean-build

clean-build:
	rm -rf "bin/$$KERNEL_CONFIG_TARGET/"
else
all:
	@true
%:
	@true
endif
