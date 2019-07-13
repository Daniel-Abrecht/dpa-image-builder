#!/bin/sh

if [ -z "project_root" ]; then
  echo "Error: project_root is not set! THis script has to be called from the makefile build env" >&2
  exit 1
fi

set -ex

# Make sure the current working directory is correct
cd "$(dirname "$0")/.."
base="$PWD"

# If not root, fake being root using user namespace. Map root -> user and 1-subuidcount to subuidmin-subuidmax
if [ $(id -u) != 0 ]
then
  exec uexec --allow-setgroups "$(realpath "$0")" "$@"
fi
tmp="$base/build/$IMAGE_NAME/"

# Cleanup if any of the remaining steps fails
cleanup(){
  set +e
  rm -rf "$tmp/rootfs" "$tmp/bootfs"
}
trap cleanup EXIT

# Remove old files from previous runs
rm -rf "$tmp/rootfs" "$tmp/bootfs"
rm -f "$tmp/rootfs.tar" "$tmp/bootfs.tar" "$tmp/device_nodes"

# Create temporary directories
mkdir -p "$tmp/rootfs"

sanitize_pkg_list(){
  sed 's/#.*//' | tr '\n' ',' | sed 's/\(,\|\s\)\+/,/g' | sed 's/^,\+\|,\+$//g'
}

mkdir -p "$tmp/rootfs/root/post_debootstrap/"
# TODO: copy scripts

if [ -n "$PACKAGES_INSTALL_DEBOOTSTRAP" ]; then debootstrap_include="--include=$(printf "%s" "$PACKAGES_INSTALL_DEBOOTSTRAP" | tr ' ' ',')"; fi

# Create usable first-stage rootfs
debootstrap --foreign --arch=arm64 $debootstrap_include "$RELEASE" "$tmp/rootfs" "$REPO"

touch "$tmp/rootfs/dev/null" # yes, this is a really bad idea, but hacking together a fuse file system just for this is overkill. Also, unionfs-fuse won't work here (fuse default is mounting as nodev), and there is no way to create a proper device file.
chmod 666 "$tmp/rootfs/dev/null"
mkdir -p "$tmp/rootfs/root/helper"
echo '#!/bin/sh' >"$tmp/rootfs/root/helper/mknod" # Don't worry about this, on boot, the kernel mounts /dev as devtmpfs before calling init anyway
echo '#!/bin/sh' >"$tmp/rootfs/root/helper/mount"
chmod +x "$tmp/rootfs/root/helper/"*

chroot_qemu_static.sh "$tmp/rootfs/" /debootstrap/debootstrap --second-stage

mkdir -p "$tmp/rootfs/root/temp-repo/"
cp kernel/bin/linux-image.deb kernel/bin/linux-libc.deb kernel/bin/linux-headers.deb "$tmp/rootfs/root/temp-repo/"
cp chroot-build-helper/bin/"$DISTRO"/"$RELEASE"/deb-*/*.deb "$tmp/rootfs/root/temp-repo/"

# Note: The /etc/fstab is generated in assemble_image.sh
(
  cd "$base/rootfs_custom_files/"
  find | while IFS= read -r file
  do
    file="$(printf "%s" "$file" | sed 's|::[^/]*$||')"
    if   [ -e "$file::$DISTRO-$RELEASE::$VARIANT" ]
      then source="$file::$DISTRO-$RELEASE::$VARIANT"
    elif [ -e "$file::$DISTRO-$RELEASE" ]
      then source="$file::$DISTRO-$RELEASE"
    elif [ -e "$file::$DISTRO::$VARIANT" ]
      then source="$file::$DISTRO::$VARIANT"
    elif [ -e "$file::$DISTRO" ]
      then source="$file::$DISTRO"
    elif [ -e "$file::$VARIANT" ]
      then source="$file::$VARIANT"
    elif [ -e "$file" ]
      then source="$file"
      else continue
    fi
    if [ -d "$source" ]
      then continue
    fi
    dir="$tmp/rootfs/$(dirname "$source")"
    mkdir -p "$dir"
    case "$file" in
      *.in)
        target="$dir/$(basename "$file" .in)"
        # The sed stuff allows escaping $ using $$
        sed 's/\$\$/\x1/g' <"$source" | envsubst | sed 's/\x1/\$/g' >"$target"
      ;;
      *.rm)
        target="$dir/$(basename "$file" .rm)"
	rm "$target"
      ;;
      *) cp "$source" "$dir/$(basename "$file")" ;;
    esac
  done
)

# Packages to install on device
printf '%s\n' $PACKAGES_INSTALL_TARGET > "$tmp/rootfs/root/packages_to_install"

# Temporary source list
(
  export CHROOT_REPO="$REPO" 
  ./script/getrfsfile.sh "rootfs_custom_files/etc/apt/sources.list"
  for file in "rootfs_custom_files/etc/apt/sources.list.d/"*
    do ./script/getrfsfile.sh "$(printf "%s" "$file" | sed 's|::[^/]*$||')" || true
  done
  echo
  echo 'deb file:///root/temp-repo/ ./'
) >"$tmp/rootfs/root/temporary-local-repo.list"

# Do some stuff inside the chroot
(
  cp script/rootfs_setup.sh "$tmp/rootfs/root/rootfs_setup.sh"
  chroot_qemu_static.sh "$tmp/rootfs/" /root/rootfs_setup.sh
  rm "$tmp/rootfs/root/rootfs_setup.sh"
)

# Cleanup
rm -f "$tmp/rootfs/etc/hostname"

# Split /boot and /
mv "$tmp/rootfs/boot" "$tmp/bootfs"
mkdir "$tmp/rootfs/boot"

rm -rf "$tmp/rootfs/root/helper"
rm -f "$tmp/rootfs/dev/null"
rm -f "$tmp/rootfs/dev/urandom"

# Create tar archives and remove tared directories
cd "$tmp/rootfs"
tar cf "$tmp/rootfs.tar" .
cd "$tmp/bootfs"
tar cf "$tmp/bootfs.tar" .
cd "$base"
