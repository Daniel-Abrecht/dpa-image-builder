#!/bin/sh

if [ -z "$project_root" ]; then
  echo "Error: project_root is not set! This script has to be called from the makefile build env" >&2
  exit 1
fi

set -ex

[ -n "$BOOT_FSTYPE" ] || BOOT_FSTYPE=ext2
[ -n "$BOOT_DIR"    ] || BOOT_DIR=boot

export BOOT_FSTYPE BOOT_DIR

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
sfdisk -J "$tmp/$IMAGE_NAME"
partitions="$(sfdisk -J "$tmp/$IMAGE_NAME" | jq -r '.partitiontable.partitions[] | "start=\(.start) size=\(.size) type=\(.type) bootable=\(.bootable // false) PARTUUID=\(.uuid // "" | ascii_downcase)"')"
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
  printf "%s\n" "$partinfos" >"$tmp/pinfo$i"
  if [ -n "$part_name" ]
  then
    ln -s "part$i" "$tmp/part-$part_name"
    printf "%s\n" "$partinfos" >"$tmp/pinfo-$part_name"
  fi
done

export bootdev="$tmp"/part-boot
export rootdev="$tmp"/part-root

[ -f "$bootdev" ]
[ -f "$rootdev" ]

PARTUUID_boot="$(. "$tmp/pinfo-boot"; echo "$PARTUUID")"
PARTUUID_root="$(. "$tmp/pinfo-root"; echo "$PARTUUID")"

export rmkld=
export mkfsoptions=
case "$FSTYPE" in
  ext?)
      rmkld=1
      mkfsoptions="$mkfsoptions -L root -E discard -O encrypt -U $PARTUUID_root -d ."
      echo "UUID=$PARTUUID_root" >> "$tmp/pinfo-root"
    ;;
  f2fs) mkfsoptions="$mkfsoptions -l root -O extra_attr,inode_checksum,compression,inode_crtime,lost_found,encrypt" ;; # Can't enable "quota", sload.f2fs doesn't handle it properly...
  vfat) mkfsoptions="$bootmkfsoptions -n root" ;;
esac

export bmkld=
export bootmkfsoptions=
case "$BOOT_FSTYPE" in
  ext?)
      bmkld=1
      bootmkfsoptions="$bootmkfsoptions -L boot -E discard -U $PARTUUID_boot -d ./$BOOT_DIR/"
      echo "UUID=$PARTUUID_boot" >> "$tmp/pinfo-boot"
    ;;
  f2fs) bootmkfsoptions="$bootmkfsoptions -l boot -O inode_checksum,compression,inode_crtime,lost_found" ;;
  vfat) bootmkfsoptions="$bootmkfsoptions -n boot -F 32" ;;
esac

if [ -z "$bmkld" ]
  then "mkfs.$BOOT_FSTYPE" $bootmkfsoptions "$bootdev"
fi
if [ -z "$rmkld" ]
  then "mkfs.$FSTYPE" $mkfsoptions "$rootdev"
fi

"$base/platform/$BUILDER_PLATFORM/install-bootloader.sh"

# Inject UUID into fstab, update initramfs, & write data to partitions
# This is done in an overlay, the changes will only apply to the data written to the image
imgdir="$tmp" OLDPATH="$PATH" CHNS_EXTRA='(
  PATH="$OLDPATH"
  set -x
  for part in "$imgdir/"part*
  do (
    part_name="$(basename "$part" | sed "s/^part-\?//")"
    part_info="$imgdir/$(basename "$part" | sed "s/^part/pinfo/")"
    . "$part_info"
    eval "$(blkid -p "$part" | sed "s/^[^:]*: //")"
    FSTAB_ID=
    if [ -n "$UUID" ]
    then
      FSTAB_ID="UUID=$UUID"
      sed -i "s/{UUID_$part_name}/$UUID/" $PATCH_DEV_FILES
    fi
    if [ -n "$PARTUUID" ]
    then
      FSTAB_ID="PARTUUID=$PARTUUID"
      sed -i "s/{PARTUUID_$part_name}/$PARTUUID/" $PATCH_DEV_FILES
    fi
    if [ -n "$FSTAB_ID" ]
      then sed -i "s/{FSTAB_$part_name}/$FSTAB_ID/" $PATCH_DEV_FILES
    fi
  ); done
)' CHNS_OVERLAY=1 CHNS_EXTRA_POST='(
  PATH="$OLDPATH"
  umount -lr proc || true
  set -x
  # Format boot partitions. May already load rootfs.
  if [ -n "$bmkld" ]
    then "mkfs.$BOOT_FSTYPE" $bootmkfsoptions "$imgdir/part-boot"
    else "sload.$BOOT_FSTYPE" -P -f "./$BOOT_DIR/" "$imgdir/part-boot"
  fi
  mount -t tmpfs none "./$BOOT_DIR/"
  # Format root partitions. May already load rootfs.
  if [ -n "$rmkld" ]
    then "mkfs.$FSTYPE" $mkfsoptions "$imgdir/part-root"
    else "sload.$FSTYPE" -P -f "./" "$imgdir/part-root"
  fi
  umount "./$BOOT_DIR/"
)' chns "$rootfsdir" update-initramfs -u

# Unmount & remove fuse loop devices
umount_wait

# Copy finished image
mv "$tmp/$IMAGE_NAME" "bin/$IMAGE_NAME"
