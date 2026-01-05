#!/bin/sh

set -ex

bootloaderdev="$tmp"/part-loader
[ -f "$bootloaderdev" ]
dd conv=notrunc,sync bs=1024 if="$BOOTLOADER_BIN" of="$bootloaderdev"
