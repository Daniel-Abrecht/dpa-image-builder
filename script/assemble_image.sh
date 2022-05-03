#!/bin/sh

if [ -z "$project_root" ]; then
  echo "Error: project_root is not set! This script has to be called from the makefile build env" >&2
  exit 1
fi

set -ex

[ -n "$BOOT_FSTYPE" ] || BOOT_FSTYPE=ext2
[ -n "$BOOT_DIR"    ] || BOOT_DIR=boot

# Make sure the current working directory is correct
cd "$(dirname "$0")/.."
export base="$PWD"

# Make sure sbin is in path, tools like sload.f2fs are in there
PATH="/sbin:/usr/sbin:$PATH"

export rootfsdir="$base/build/$IMAGE_NAME/root.fs"

if [ -z "$IMGSIZE" ] || [ "$IMGSIZE" = auto ]; then
  rootfs_size="$(uexec du --block-size=1 -s "$rootfsdir" | grep -o '^[0-9]*')"
  IMGSIZE="$(expr "$(expr "$(expr "$rootfs_size" \* 120 / 100 + 268435456 + 2048 + 1023)" / 1024 + 1023)" / 1024 + 1024)"MiB
fi

export tmp="$(mktemp -d -p "$base/build")"

# if there is an old temporary image, remove it
rm -f "$tmp/$IMAGE_NAME"

# Create a sparse image
truncate -s "$IMGSIZE" "$tmp/$IMAGE_NAME"

# Create partitions
part_file="$base/platform/$BUILDER_PLATFORM/part.sfdisk"
sfdisk "$tmp/$IMAGE_NAME" <"$part_file"

# Get partition offsets
partitions="$(sfdisk -J "$tmp/$IMAGE_NAME" | jq -r '.partitiontable.partitions[] | "start=\(.start) size=\(.size) type=\(.type) bootable=\(.bootable)"')"
partition_names="$(sed 's/#.*//' <"$part_file" | grep -v ':\|^$' | sed 's/.*\(name=\([^ ,]*\)\).*\|.*/\2/')"

# Unmount & remove fuse loop devices
umount_wait(){
  ## umount mountpoint
  for part in "$tmp"/part*
  do
    if [ -h "$part" ]
      then continue
    fi
    # Unmount partitions. Using -z because we may get EBUSY otherwise. Unfortunately, we don't know when it's done this way
    mountpoint -q "$part" && fusermount -zu "$part"
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
trap cleanup EXIT INT TERM

# This is the default for most tools. Don't change this, the other commands in this script haven't been adjusted to use this instead of the default.
blocksize=512

# Mount partitions as files using fuse
i=0
printf '%s\n' "$partitions" |
while read partinfos
do
  i=$((i + 1))
  eval "$partinfos"
  touch "$tmp/part$i"
  fuseloop -O "$(expr "$start" \* $blocksize)" -S "$(expr "$size" \* $blocksize)" "$tmp/$IMAGE_NAME" "$tmp/part$i"
  part_name="$(printf "%s\n" "$partition_names" | sed "$i"'q;d')"
  if [ -n "$part_name" ]
    then ln -s "part$i" "$tmp/part-$part_name"
  fi
done

export bootdev="$tmp"/part-boot
export rootdev="$tmp"/part-root

[ -f "$bootdev" ]
[ -f "$rootdev" ]

mkfsoptions=
case "$FSTYPE" in
  ext?) mkfsoptions="$mkfsoptions -L root -E discard -O encrypt" ;;
  f2fs) mkfsoptions="$mkfsoptions -l root -O extra_attr,inode_checksum,compression,inode_crtime,lost_found,encrypt" ;; # Can't enable "quota", sload.f2fs doesn't handle it properly...
  vfat) bootmkfsoptions="$bootmkfsoptions -n root" ;;
esac

bootmkfsoptions=
case "$BOOT_FSTYPE" in
  ext?) bootmkfsoptions="$bootmkfsoptions -L boot -E discard" ;;
  f2fs) bootmkfsoptions="$bootmkfsoptions -l boot -O inode_checksum,compression,inode_crtime,lost_found" ;;
  vfat) bootmkfsoptions="$bootmkfsoptions -n boot -F 32" ;;
esac

# Format partitions
"mkfs.$BOOT_FSTYPE" $bootmkfsoptions "$bootdev"
"mkfs.$FSTYPE" $mkfsoptions "$rootdev"

"$base/platform/$BUILDER_PLATFORM/install-bootloader.sh"

# Write data to partitions
uexec "sload.$BOOT_FSTYPE" -P -f "$rootfsdir/$BOOT_DIR/" "$bootdev"
uexec unshare -m sh -ex -c "mount -t tmpfs none \"\$rootfsdir/$BOOT_DIR/\"; \"sload.\$FSTYPE\" -P -f \"\$rootfsdir\" \"\$rootdev\"; umount \"\$rootfsdir/$BOOT_DIR/\""

# Unmount & remove fuse loop devices
umount_wait

# Copy finished image
mv "$tmp/$IMAGE_NAME" "bin/$IMAGE_NAME"
