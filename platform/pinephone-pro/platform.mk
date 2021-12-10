export UBOOT_DIR = $(project_root)/platform/$(BUILDER_PLATFORM)/uboot/
export BOOTLOADER_BIN = $(UBOOT_DIR)/bin/u-boot.bin

PLATFORM_FILES = $(BOOTLOADER_BIN)

$(BOOTLOADER_BIN):
	make -c $(UBOOT_DIR)
