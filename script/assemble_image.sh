#!/bin/sh

if [ -z "$project_root" ]; then
  echo "Error: project_root is not set! This script has to be called from the makefile build env" >&2
  exit 1
fi

set -xe

if [ -z "$IMGSIZE" ] || [ "$IMGSIZE" = auto ]; then
  rootfs_size="$(stat -c '%s' "build/$IMAGE_NAME/rootfs.tar")"
  IMGSIZE="$(expr "$(expr "$(expr "$rootfs_size" \* 120 / 100 + 268435456 + 2048 + 1023)" / 1024 + 1023)" / 1024 + 1024)"MiB
fi

cd "$(dirname "$0")/.."
base="$PWD"

tmp="$(mktemp -d -p build)"

# if there is an old temporary image, remove it
rm -f "$tmp/$IMAGE_NAME"

# Create a sparse image
truncate -s "$IMGSIZE" "$tmp/$IMAGE_NAME"

# Create partitions
sfdisk "$tmp/$IMAGE_NAME" <<EOF
label: dos
unit: sectors

# Protective partition for Cortex M4 firmware and ARM trusted platform + uboot bootloader
start=4, size=4092, type=da
# /boot/ partition
size=256MiB, type=83, name=boot, bootable
# / partition, use remaining space
type=83, name=root
EOF

# Get partition offsets
IFSOLD="$IFS"
IFS=
partitions="$(sfdisk -J "$tmp/$IMAGE_NAME" | jq -r '.partitiontable.partitions[] | "start=\(.start) size=\(.size) type=\(.type) bootable=\(.bootable)"')"
IFS="$OLDIFS"

# Unmount & remove fuse loop devices
umount_wait(){
  ## umount mountpoint
  for part in "$tmp"/part*
  do
    # Unmount partitions. Using -z because we may get EBUSY otherwise. Unfortunately, we don't know when it's done this way
    mountpoint -q "$part" && fusermount -zu "$part"
  done
  # Wait until nothing is accessing the file anymore
  while lsof "$tmp/$IMAGE_NAME" >/dev/null
    do sleep 0.1
  done
  # remove fuse loop devices
  rm -f "$tmp"/part*
}

# Cleanup if any of the following commands fail and after this script finishes
cleanup(){
  set +e
  umount_wait
  rm -rf "$tmp"
}
trap cleanup EXIT

# This is the default for most tools. Don't change this, the other commands in this script haven't been adjusted to use this instead of the default.
blocksize=512

# Mount partitions as files using fuse
i=0
printf '%s\n' "$partitions" |
while read partinfos
do
  eval "$partinfos"
  touch "$tmp/part$i"
  fuseloop -O "$(expr "$start" \* $blocksize)" -S "$(expr "$size" \* $blocksize)" "$tmp/$IMAGE_NAME" "$tmp/part$i"
  i=$(expr $i + 1)
done

bootloaderdev="$tmp"/part0
bootdev="$tmp"/part1
rootdev="$tmp"/part2

m4_size=$(stat -c "%s" uboot/firmware/m4.bin)
if [ $m4_size -gt 31744 ]; then # 31744 = 1024 * 31
  echo "The M4 firmware is too big, it would overlap with the uboot loader, aborting." >&2
  exit 1
fi

# Copy m4 firmware to image
dd conv=notrunc,sync if=uboot/firmware/m4.bin of="$bootloaderdev" bs=1024
# Copy uboot bootloader to image
dd conv=notrunc,sync if=uboot/bin/uboot_firmware_and_dtb.bin of="$bootloaderdev" bs=1024 seek=31

# Format partitions
mkfs.ext2 -L boot "$bootdev"
mkfs.ext4 -L root -E discard "$rootdev"

# Write rootfs to partitions
writeTar2Ext "$bootdev" < "build/$IMAGE_NAME/bootfs.tar"
writeTar2Ext "$rootdev" < "build/$IMAGE_NAME/rootfs.tar"

# Unmount & remove fuse loop devices
umount_wait

# Copy finished image
cp "$tmp/$IMAGE_NAME" "bin/$IMAGE_NAME"
