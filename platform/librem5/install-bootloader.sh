#!/bin/sh

set -ex

bootloaderdev="$tmp"/part-firmware

[ -f "$bootloaderdev" ]

m4_size=$(stat -c "%s" "$M4_FIRMWARE_BIN")
if [ $m4_size -gt 31744 ]; then # 31744 = 1024 * 31
  echo "The M4 firmware is too big, it would overlap with the uboot loader, aborting." >&2
  exit 1
fi

# Copy m4 firmware to image
dd conv=notrunc,sync if="$M4_FIRMWARE_BIN" of="$bootloaderdev" bs=1024
# Copy uboot bootloader to image
dd conv=notrunc,sync if="$BOOTLOADER_BIN" of="$bootloaderdev" bs=1024 seek=31
