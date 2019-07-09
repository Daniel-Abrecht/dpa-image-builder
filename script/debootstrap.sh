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
if [ -z "$DISTRO" ]; then DISTRO=devuan; fi
if [ -z "$RELEASE" ]; then RELEASE=ascii; fi
if [ -z "$VARIANT" ]; then VARIANT=base; fi
if [ -z "$IMAGE_NAME" ]; then IMAGE_NAME="$DISTRO-$RELEASE-librem5-devkit-$(VARIANT).img"; fi
if [ -z "$REPO" ]; then REPO=https://pkgmaster.devuan.org/merged/; fi
if [ -z "$CHROOT_REPO" ]; then CHROOT_REPO="$REPO"; fi
if [ -z "$KERNEL_DTB" ]; then echo "Pleas set KERNEL_DTB" >2; exit 1; fi

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

packages=
packages_early=
packages_second_stage=
packages_download_only=
packages_exclude_debootstrap=

mkdir -p "$tmp/rootfs/root/post_debootstrap/"

i=0
for spec in "default" "default::$VARIANT" "$DISTRO-$RELEASE::$VARIANT" "$DISTRO-$RELEASE" "$DISTRO::$VARIANT" "$DISTRO"
do
  i="$(expr "$i" + 1)"
  packages_base="packages/$spec/"
  if [ -f "$packages_base/install_debootstrap" ]
    then packages="$packages $(sanitize_pkg_list < "$packages_base/install_debootstrap")"
  fi
  if [ -f "$packages_base/download" ]
    then packages_download_only="$packages_download_only $(sanitize_pkg_list < "$packages_base/download")"
  fi
  if [ -f "$packages_base/install_early" ]
    then packages_early="$packages_early $(sanitize_pkg_list < "$packages_base/install_early")"
  fi
  if [ -f "$packages_base/install_second_stage" ]
    then packages_second_stage="$packages_second_stage $(sanitize_pkg_list < "$packages_base/install_second_stage")"
  fi
  if [ -f "$packages_base/debootstrap_exclude" ]
    then packages_exclude_debootstrap="$packages_exclude_debootstrap $(sanitize_pkg_list < "$packages_base/debootstrap_exclude")"
  fi
  if [ -x "$packages_base/post_debootstrap" ]
    then cp "$packages_base/post_debootstrap" "$tmp/rootfs/root/post_debootstrap/$i-$spec.sh"
  fi
done

if [ "$AARCH64_EXECUTABLE" != yes ]
  then packages="$packages,fakechroot"
fi

# Add packages for different apt transport if any is used
if echo "$CHROOT_REPO" | grep -o '^[^:]*' | grep -q 'https'    ; then packages="$packages,apt-transport-https"    ; fi
if echo "$CHROOT_REPO" | grep -o '^[^:]*' | grep -q 'tor'      ; then packages="$packages,apt-transport-tor"      ; fi
if echo "$CHROOT_REPO" | grep -o '^[^:]*' | grep -q 'spacewalk'; then packages="$packages,apt-transport-spacewalk"; fi

packages="$(echo "$packages" | sanitize_pkg_list)"
if [ -n "$packages" ]; then packages="--include=$packages"; fi
if [ -n "$packages_exclude_debootstrap" ]; then packages_exclude_debootstrap="--exclude=$packages_exclude_debootstrap"; fi

# Create usable first-stage rootfs
debootstrap --foreign --arch=arm64 $packages_exclude_debootstrap $packages "$RELEASE" "$tmp/rootfs" "$REPO"

touch "$tmp/rootfs/dev/null" # yes, this is a really bad idea, but hacking together a fuse file system just for this is overkill. Also, unionfs-fuse won't work here (fuse default is mounting as nodev), and there is no way to create a proper device file.
chmod 666 "$tmp/rootfs/dev/null"
mkdir "$tmp/rootfs/root/helper"
echo '#!/bin/sh' >"$tmp/rootfs/root/helper/mknod" # Don't worry about this, on boot, the kernel mounts /dev as devtmpfs before calling init anyway
echo '#!/bin/sh' >"$tmp/rootfs/root/helper/mount"
chmod +x "$tmp/rootfs/root/helper/"*

chroot_qemu_static.sh "$tmp/rootfs/" /debootstrap/debootstrap --second-stage

mkdir "$tmp/rootfs/root/temp-repo/"
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
echo "$packages_second_stage" | tr ',' '\n' > "$tmp/rootfs/root/packages_to_install"

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
  export packages="$packages_second_stage $packages_download_only"
  export install_packages="$packages_early"
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
