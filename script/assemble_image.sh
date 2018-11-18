#!/bin/sh

set -xe

cd "$(dirname "$0")/.."
base="$PWD"

tmp="$(mktemp -d)"

if [ -z "$RELEASE" ]; then RELEASE="ascii"; fi
if [ -z "$IMAGE_NAME" ]; then IMAGE_NAME="devuan-$RELEASE-librem5-devkit-base.img"; fi

# Some programs like sfdisk are in /sbin/, but they work just fine as non-root on an image
PATH="$base/build/bin/:$base/script/:/sbin/:/usr/sbin/:$PATH"

# Set image size if not already defined
if [ -z "$IMGSIZE" ]; then IMGSIZE=32GB; fi

# if there is an old temporari image, remove it
rm -f "$tmp/$IMAGE_NAME"

# Create a sparse image
truncate -s "$IMGSIZE" "$tmp/$IMAGE_NAME"

# Create partitions
sfdisk "$tmp/$IMAGE_NAME" <<EOF
label: dos
unit: sectors

# Protective partition for Cortex M4 firmware and ARM trusted platform + uboot bootloader
start=4, size=2044, type=da
# /boot/ partition
start=2048, size=256MiB, type=83, bootable
# / partition, use remaining space
type=83
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
mkfs.ext2 "$bootdev"
mkfs.ext4 -E discard "$rootdev"

UUID_boot="$(/sbin/tune2fs -l "$bootdev" | grep 'Filesystem UUID' | grep -o '[^ ]*$')"
UUID_root="$(/sbin/tune2fs -l "$rootdev" | grep 'Filesystem UUID' | grep -o '[^ ]*$')"

(
  cd "$tmp"
  mkdir etc
  cat >etc/fstab <<EOF
# <file system>		<mount point>	<type>	<options>				<dump>  <pass>
proc			/proc		proc	nosuid,noexec,nodev,hidepid=2		0	0
UUID=$UUID_root		/		ext4	discard,relatime,errors=remount-ro	0	1
UUID=$UUID_boot		/boot		ext2    ro,relatime				0	1
tmpfs			/tmp		tmpfs	defaults,noexec,nosuid,nodev		0	0
EOF
  rm -f fstab.tar
  tar cf fstab.tar ./etc/fstab
  rm etc/fstab
  rmdir etc
)

# Write rootfs to partitions
writeTar2Ext "$bootdev" < build/filesystem/bootfs-$RELEASE.tar
writeTar2Ext "$rootdev" < build/filesystem/rootfs-$RELEASE.tar
writeTar2Ext "$rootdev" < "$tmp/fstab.tar"

# Unmount & remove fuse loop devices
umount_wait

# Copy finished image
cp "$tmp/$IMAGE_NAME" "bin/$IMAGE_NAME"
