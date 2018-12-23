#!/bin/sh

set -ex

# Make sure the current working directory is correct
cd "$(dirname "$0")/.."
base="$PWD"

# Make sure debootstrap & co is in path, and that the fake mknod noop helper will be used
PATH="$base/build/bin/:$base/script/:/sbin/:/usr/sbin/:$PATH"

# If not root, fake being root using user namespace. Map root -> user and 1-subuidcount to subuidmin-subuidmax
if [ $(id -u) != 0 ]
then
  exec uexec "$(realpath "$0")" "$@"
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
  rm -rf "$tmp/rootfs" "$tmp/bootfs" "$tmp/downloaded_packages/"
  rm -f "$tmp/debootstrap.tar.gz"
}
trap cleanup EXIT

# Remove old files from previous runs
rm -rf "$tmp/rootfs" "$tmp/bootfs" "$tmp/downloaded_packages/"
rm -f "$tmp/rootfs.tar" "$tmp/bootfs.tar" "$tmp/debootstrap.tar.gz" "$tmp/device_nodes"

# Create temporary directories
mkdir -p "$tmp/rootfs"

sanitize_pkg_list(){
  tr '\n' ',' | sed 's/\(,\|\s\)\+/,/g' | sed 's/^,\+\|,\+$//g'
}

packages_second_stage="$(sanitize_pkg_list < include_packages)"
packages="$(sanitize_pkg_list < include_packages_early)"

# Add packages for different apt transport if any is used
if echo "$CHROOT_REPO" | grep -o '^[^:]*' | grep -q 'https'    ; then packages="$packages,apt-transport-https"    ; fi
if echo "$CHROOT_REPO" | grep -o '^[^:]*' | grep -q 'tor'      ; then packages="$packages,apt-transport-tor"      ; fi
if echo "$CHROOT_REPO" | grep -o '^[^:]*' | grep -q 'spacewalk'; then packages="$packages,apt-transport-spacewalk"; fi

packages="$(echo "$packages" | sanitize_pkg_list)"
if [ -n "$packages" ]; then packages="--include=$packages"; fi

# Create usable first-stage rootfs
debootstrap --foreign --arch=arm64 $packages "$RELEASE" "$tmp/rootfs" "$REPO"

if [ -n "$packages_second_stage" ]
then
  debootstrap --foreign --arch=arm64 --download-only --include="$packages_second_stage" "$RELEASE" "$tmp/downloaded_packages/" "$REPO"
  echo "$packages_second_stage" | tr ',' '\n' > "$tmp/rootfs/root/packages_to_install"
  cp "$tmp/downloaded_packages/var/cache/apt/archives/"*.deb "$tmp/rootfs/var/cache/apt/archives/"
fi

# I've seen init not getting unpacked by debootstrap --foreign in devuan beowulf but only after the debootstrap --second stage
if [ ! -f "$tmp/rootfs/sbin/init" ]
then
  echo "Warning: /sbin/init doesn't exist in first-stage debootstraped rootfs yet. Assuming creation in second stage."
fi

# Extract kernel packages. Properly installing them later is still required.
for package in kernel/bin/linux-*.deb
do
  dpkg -x "$package" "$tmp/rootfs"
  cp "$package" "$tmp/rootfs/root/"
done

# Create symlink for /boot/vmlinuz -> vmlinuz-...
# Note: The image and device tree are later updated using the /etc/kernel/postinst.d/update-zImage script on kernel updates too
vmlinuz="$(basename "$tmp/rootfs/boot/"vmlinuz-*)"
ln -sf "$vmlinuz" "$tmp/rootfs/boot/vmlinuz"
# copy flat device tree binary
ext="$(printf "%s" "$vmlinuz" | tail -c +9)"
# Write dtb file to use to etc/dtb_file, for later use in later kernel updates
echo "$KERNEL_DTB" > "$tmp/rootfs/etc/dtb_file"
dtb="linux-image-$ext/$(cat $tmp/rootfs/etc/dtb_file)"
mkdir -p "$tmp/rootfs/boot/$(dirname "$dtb")"
cp "$tmp/rootfs/usr/lib/$dtb" "$tmp/rootfs/boot/$dtb"
# Update flat device tree binary symlink
ln -sf "$dtb" "$tmp/rootfs/boot/devicetree"

mv "$tmp/rootfs/sbin/init" "$tmp/rootfs/sbin/init_real" || true

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
        envsubst <"$file" >"$target"
      ;;
      *) cp "$file" "$dir" ;;
    esac
  done
)

# Create boot.scr from boot.txt
rm -f "$tmp/rootfs/boot/boot.scr"
./uboot/bin/mkimage_uboot -A arm -T script -O linux -d "$tmp/rootfs/boot/boot.txt" "$tmp/rootfs/boot/boot.scr"

# TODO: Get rid of this and let uboot do the decompressing
gzip -d < "$tmp/rootfs/boot/vmlinuz" > "$tmp/rootfs/boot/vmlinux"

# Split /boot and /
mv "$tmp/rootfs/boot" "$tmp/bootfs"
mkdir "$tmp/rootfs/boot"

# Create tar archives and remove tared directories
cd "$tmp/rootfs"
tar cf "$tmp/rootfs-$RELEASE.tar" .
cd "$tmp/bootfs"
tar cf "$tmp/bootfs-$RELEASE.tar" .
cd "$base"
