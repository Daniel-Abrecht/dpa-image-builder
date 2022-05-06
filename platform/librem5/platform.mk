export UBOOT_DIR = $(project_root)/platform/$(BUILDER_PLATFORM)/uboot/
export BOOTLOADER_BIN = $(UBOOT_DIR)/bin/$(UBOOT_CONFIG_TARGET)/uboot_firmware_and_dtb.bin
export M4_FIRMWARE_BIN = $(UBOOT_DIR)/firmware/m4.bin

PLATFORM_FILES = $(BOOTLOADER_BIN)

bootloader: $(BOOTLOADER_BIN)
	@true

$(BOOTLOADER_BIN):
	$(MAKE) -C $(UBOOT_DIR)

uuu-do-%: script/uuu/%.lst build/.dir
	# The sed stuff allows escaping $ using $$ in envsubst
	set -e; \
	export UBOOT_BIN; \
	tmplstfile="build/uuu-script.lst"; \
	cleanup(){ rm -f "$$tmplstfile"; }; \
	cleanup; \
	trap cleanup EXIT; \
	sed 's/\$$\$$/\x1/g' <"$<" | envsubst | sed 's/\x1/\$$/g' >"$$tmplstfile"; \
	uuu "$$tmplstfile";

uuu-uboot-do-%: script/uuu/%.lst $(BOOTLOADER_BIN)
	$(MAKE) UBOOT_BIN=$(BOOTLOADER_BIN) uuu-do-$(patsubst uuu-uboot-do-%,%,$@)

uuu-image-do-%: script/uuu/%.lst build/.dir
	# To determine the real size of the uboot binary is too complicated
	# instead, let's just assume 2MB are enough, its usually ~1M.
	# That's no problem for booting, just don't flash it.
	# A bigger size will fail to download, the offset wraps around...
	# (may be mitigateable by increasing the buffer size)
	set -e; \
        if [ "$(IMAGE_UBOOT_UNFLASHABLE)" = "1" ]; \
	then \
	  uboot="$(BOOTLOADER_BIN)"; \
	else \
	  uboot="build/extracted_uboot"; \
	  cleanup(){ rm -f "$$uboot"; }; \
	  cleanup; \
	  trap cleanup EXIT; \
	  dd if="bin/$(IMAGE_NAME)" of="$$uboot" bs=512 skip=66 count=4000; \
	fi; \
	$(MAKE) UBOOT_BIN="$$uboot" uuu-do-$(patsubst uuu-image-do-%,%,$@)

uuu-test-uboot: uuu-uboot-do-test-uboot
	@true

uuu-test-uboot//image: uuu-image-do-test-uboot
	@true

uuu-uboot-flash: uuu-uboot-do-uboot-flash
	@true

uuu-flash uuu-flash//image: uuu-image-do-flash
	@true

uuu-test-kernel: kernel/bin/linux-image.deb
	ar p kernel/bin/linux-image.deb data.tar.xz | tar xJ --wildcards './boot/vmlinuz-*' -O | gunzip > build/vmlinux
	ar p kernel/bin/linux-image.deb data.tar.xz | tar xJ --wildcards './usr/lib/linux-image-*/$(KERNEL_DTB)' -O > build/dtb
	$(MAKE) uuu-uboot-do-test-kernel || true
	rm build/vmlinux
	rm build/dtb
