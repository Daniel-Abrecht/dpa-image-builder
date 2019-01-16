#!/bin/sh

if [ -z "$AARCH64_EXECUTABLE" ]
  then echo "Warning: AARCH64_EXECUTABLE is not set! (Note: This script is expected to be called by the make file)" >&2
fi

set -ex

# Make sure the current working directory is correct
cd "$(dirname "$0")/.."
base="$PWD"

# Make sure debootstrap & co is in path, and that the fake mknod noop helper will be used
PATH="$base/build/bin/:$base/script/:/sbin/:/usr/sbin/:$PATH"

# If not root, fake being root using user namespace. Map root -> user and 1-subuidcount to subuidmin-subuidmax
if [ $(id -u) != 0 ]
then
  exec uexec --allow-setgroups "$(realpath "$0")" "$@"
fi

# Set release repo if not already defined
if [ -z "$RELEASE" ]; then RELEASE=ascii; fi
if [ -z "$REPO" ]; then REPO=https://pkgmaster.devuan.org/merged/; fi
if [ -z "$CHROOT_REPO" ]; then CHROOT_REPO="$REPO"; fi
if [ -z "$KERNEL_DTB" ]; then echo "Pleas set KERNEL_DTB" >2; exit 1; fi

tmp="$base/build/filesystem/"

# Cleanup if any of the remaining steps fails
cleanup(){
  set +e
  if [ -n "$urandompid" ]; then kill "$urandompid" || true; fi
  rm -rf "$tmp/rootfs" "$tmp/bootfs"
}
trap cleanup EXIT

# Remove old files from previous runs
rm -rf "$tmp/rootfs" "$tmp/bootfs"
rm -f "$tmp/rootfs.tar" "$tmp/bootfs.tar" "$tmp/device_nodes"

# Create temporary directories
mkdir -p "$tmp/rootfs"

sanitize_pkg_list(){
  tr '\n' ',' | sed 's/\(,\|\s\)\+/,/g' | sed 's/^,\+\|,\+$//g'
}

packages_download_only="$(sanitize_pkg_list < packages_download_only)"
packages_second_stage="$(sanitize_pkg_list < packages_install_target)"
packages="$(sanitize_pkg_list < packages_install_debootstrap)"

packages="$packages,dpkg-dev"

if [ "$AARCH64_EXECUTABLE" != yes ]
  then packages="$packages,fakechroot"
fi

# Add packages for different apt transport if any is used
if echo "$CHROOT_REPO" | grep -o '^[^:]*' | grep -q 'https'    ; then packages="$packages,apt-transport-https"    ; fi
if echo "$CHROOT_REPO" | grep -o '^[^:]*' | grep -q 'tor'      ; then packages="$packages,apt-transport-tor"      ; fi
if echo "$CHROOT_REPO" | grep -o '^[^:]*' | grep -q 'spacewalk'; then packages="$packages,apt-transport-spacewalk"; fi

packages="$(echo "$packages" | sanitize_pkg_list)"
if [ -n "$packages" ]; then packages="--include=$packages"; fi

# Create usable first-stage rootfs
debootstrap --foreign --arch=arm64 $packages "$RELEASE" "$tmp/rootfs" "$REPO"

touch "$tmp/rootfs/dev/null" # yes, this is a really bad idea, but hacking together a fuse file system just for this is overkill. Also, unionfs-fuse won't work here (fuse default is mounting as nodev), and there is no way to create a proper device file.
chmod 666 "$tmp/rootfs/dev/null"
mkdir "$tmp/rootfs/root/helper"
echo '#!/bin/sh' >"$tmp/rootfs/root/helper/mknod" # Don't worry about this, on boot, the kernel mounts /dev as devtmpfs before calling init anyway
echo '#!/bin/sh' >"$tmp/rootfs/root/helper/mount"
chmod +x "$tmp/rootfs/root/helper/"*

# Apt needs urandom for gpgv, so I have to fake it...
mkfifo "$tmp/rootfs/dev/urandom"
(
  set +ex
  while true
  do
    dd bs=1 if=/dev/urandom of="$tmp/rootfs/dev/urandom"
  done
) & urandompid=$!

chroot_qemu_static.sh "$tmp/rootfs/" /debootstrap/debootstrap --second-stage

cp kernel/bin/linux-image.deb kernel/bin/linux-libc.deb kernel/bin/linux-headers.deb "$tmp/rootfs/root/"

# Note: The /etc/fstab is generated in assemble_image.sh
(
  cd "$base/rootfs_custom_files/"
  find | while IFS= read -r file
  do
    if [ -d "$file" ]
    then
      mkdir -p "$file"
      continue
    fi
    dir="$tmp/rootfs/$(dirname "$file")"
    mkdir -p "$dir"
    case "$file" in
      *.in)
        target="$dir/$(basename "$file" .in)"
        # The sed stuff allows escaping $ using $$
        sed 's/\$\$/\x1/g' <"$file" | envsubst | sed 's/\x1/\$/g' >"$target"
      ;;
      *) cp "$file" "$dir" ;;
    esac
  done
)

# Packages to install on device
echo "$packages_second_stage" | tr ',' '\n' > "$tmp/rootfs/root/packages_to_install"

# Do some stuff inside the chroot
(
  cp script/rootfs_setup.sh "$tmp/rootfs/root/rootfs_setup.sh"
  export packages="$packages_second_stage $packages_download_only"
  chroot_qemu_static.sh "$tmp/rootfs/" /root/rootfs_setup.sh
  rm "$tmp/rootfs/root/rootfs_setup.sh"
)

# Create boot.scr from boot.txt
rm -f "$tmp/rootfs/boot/boot.scr"
./uboot/bin/mkimage_uboot -A arm -T script -O linux -d "$tmp/rootfs/boot/boot.txt" "$tmp/rootfs/boot/boot.scr"

# TODO: Get rid of this and let uboot do the decompressing
gzip -d < "$tmp/rootfs/boot/vmlinuz" > "$tmp/rootfs/boot/vmlinux"

rm -f "$tmp/rootfs/etc/hostname"

# Split /boot and /
mv "$tmp/rootfs/boot" "$tmp/bootfs"
mkdir "$tmp/rootfs/boot"

rm -rf "$tmp/rootfs/root/helper"
rm -f "$tmp/rootfs/dev/null"
rm -f "$tmp/rootfs/dev/urandom"

# Create tar archives and remove tared directories
cd "$tmp/rootfs"
tar cf "$tmp/rootfs-$RELEASE.tar" .
cd "$tmp/bootfs"
tar cf "$tmp/bootfs-$RELEASE.tar" .
cd "$base"
