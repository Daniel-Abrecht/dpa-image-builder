include ../src/make-helper-functions.mk
ifdef KERNEL_CONFIG_TARGET

.SECONDEXPANSION:

all: bin/$(KERNEL_CONFIG_TARGET)/.done
	@true

menuconfig: $$(call repodir,linux) | configs/.dir
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
	exec 8>bin/$(KERNEL_CONFIG_TARGET)/.lock; \
	flock 8; \
	if [ -f "$@" ]; then exit 0; fi; \
	with-repo.sh linux bash -ex -c '\
	  if [ -f "configs/$$KERNEL_CONFIG_TARGET" ]; \
	    then cp "configs/$$KERNEL_CONFIG_TARGET" "$$repodir/linux/arch/arm64/configs/$${KERNEL_CONFIG_TARGET}_defconfig"; \
	  fi; \
	  patchdir="$$(realpath "patch/$$KERNEL_CONFIG_TARGET/$$KERNEL_PATCHES" || true)"; \
	  if [ -n "$$KERNEL_PATCHES" ] && [ -d "$$patchdir" ]; \
	    then ( cd "$$repodir/linux"; for patch in "$$patchdir"/*.patch; do git apply "$$patch"; done ); \
	  fi; \
	  $(MAKE) --debug=n -C "$$repodir/linux" ARCH=arm64 CROSS_COMPILE="$$CROSS_COMPILER" "$$KERNEL_CONFIG_TARGET"_defconfig; \
	  if [ "$$USE_EFI" = y ]; then ( cd "$$repodir/linux"; ./scripts/config --set-val CONFIG_EFI y; make --debug=n ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig; ); fi; \
	  $(MAKE) --debug=n -C "$$repodir/linux" ARCH=arm64 CROSS_COMPILE="$$CROSS_COMPILER" KBUILD_IMAGE=arch/arm64/boot/Image bindeb-pkg \
	   || $(MAKE) --debug=n -C "$$repodir/linux" ARCH=arm64 CROSS_COMPILE="$$CROSS_COMPILER" bindeb-pkg; \
	  cp "$$repodir"/linux-*.deb "bin/$$KERNEL_CONFIG_TARGET/"; \
	'; \
	touch "$@";
	# Note: Trying to make bindeb-pkg again without KBUILD_IMAGE=arch/arm64/boot/Image if it failed, because some downstream kernels do some funny stuff (https://source.puri.sm/Librem5/linux/-/commit/038b6b85e8b7738e7081780e79bab8410ab07101#b48fea44aa4aea680003375368b4d138ebd75204)

clean-repo: clean-repo//linux
	@true

update-repo: update-repo//linux
	@true

clean-build-all:
	rm -rf "bin/"

clean-build:
	rm -rf "bin/$$KERNEL_CONFIG_TARGET/"
else
all:
	@true
%:
	@true
endif
