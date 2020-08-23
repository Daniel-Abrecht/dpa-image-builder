#!/bin/sh

if [ -z "$project_root" ]; then
  echo "Error: project_root is not set! This script has to be called from the makefile build env" >&2
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

mkdir -p "$tmp/rootfs/usr/share/first-boot-setup/post_debootstrap/"
# TODO: copy scripts

if [ -n "$PACKAGES_INSTALL_DEBOOTSTRAP" ]; then debootstrap_include="--include=$(printf "%s" "$PACKAGES_INSTALL_DEBOOTSTRAP" | tr ' ' ',')"; fi

# Create usable first-stage rootfs
DEBOOTSTRAP_DIR="$X_DEBOOTSTRAP_DIR/usr/share/debootstrap/" "$X_DEBOOTSTRAP_DIR/usr/sbin/debootstrap" --foreign --arch=arm64 $debootstrap_include "$RELEASE" "$tmp/rootfs" "$REPO" "$DEBOOTSTRAP_SCRIPT"

touch "$tmp/rootfs/dev/null" # yes, this is a really bad idea, but hacking together a fuse file system just for this is overkill. Also, unionfs-fuse won't work here (fuse default is mounting as nodev), and there is no way to create a proper device file.
chmod 666 "$tmp/rootfs/dev/null"
mkdir -p "$tmp/rootfs/root/helper"
echo '#!/bin/sh' >"$tmp/rootfs/root/helper/mknod" # Don't worry about this, on boot, the kernel mounts /dev as devtmpfs before calling init anyway
echo '#!/bin/sh' >"$tmp/rootfs/root/helper/mount"
chmod +x "$tmp/rootfs/root/helper/"*

chroot_qemu_static.sh "$tmp/rootfs/" /debootstrap/debootstrap --second-stage

mkdir -p "$tmp/rootfs/usr/share/first-boot-setup/temp-repo/"
cp kernel/bin/linux-image.deb "$tmp/rootfs/usr/share/first-boot-setup/temp-repo/"
cp kernel/bin/linux-libc.deb "$tmp/rootfs/usr/share/first-boot-setup/temp-repo/" || true
cp kernel/bin/linux-headers.deb "$tmp/rootfs/usr/share/first-boot-setup/temp-repo/" || true

for deb in chroot-build-helper/bin/"$DISTRO"/"$RELEASE"/*/*.deb
do
  if [ -f "$deb" ]
    then cp "$deb" "$tmp/rootfs/usr/share/first-boot-setup/temp-repo/"
  fi
done

for dummy in $PACKAGES_BOOTSTRAP_WORKAROUND
  do mkdummydeb.sh "$tmp/rootfs/usr/share/first-boot-setup/temp-repo/$dummy" 00
done

# Note: The /etc/fstab is generated in assemble_image.sh
rfslsdir.sh -r "rootfs" | while read t config file
do
  dir="$tmp/rootfs"
  case "$t" in
    d) mkdir -p "$dir$file" ;;
    r) rm -f "$dir$file" ;;
    f) cp -a "config/$config/rootfs$file" "$dir$file" ;;
    s)
      sed 's/\$\$/\x1/g' <"config/$config/rootfs$file.in" | envsubst | sed 's/\x1/\$/g' >"$dir$file"
      chmod --reference="config/$config/rootfs$file.in" "$dir$file"
    ;;
  esac
done

i=0
for config in $CONFIG_PATH
do
  i=$(expr $i + 1)
  for script in post_debootstrap post_early_install pre_target_install post_target_install
  do
    script_path="config/$config/$script"
    config_flat_name="$(printf "%s" "$config" | sed 's|[^a-zA-Z0-9-]|_|g')"
    script_dir_target="$tmp/rootfs/usr/share/first-boot-setup/$script"
    mkdir -p "$script_dir_target"
    if [ -d "$script_path" ]
    then
      for file in "$script_path/"*
      do [ -x "$file" ] || continue;
        filename="$(basename "$file")"
        cp "$file" "$script_dir_target/$i-$config_flat_name-$filename"
      done
    elif [ -x "$script_path" ]
      then cp "$script_path" "$script_dir_target/$i-$config_flat_name"
    fi
  done
done

# Temporary source list
(
  export CHROOT_REPO="$REPO" 
  getrfsfile.sh "rootfs/etc/apt/sources.list"
  rfslsdir.sh "rootfs/etc/apt/sources.list.d/" | grep '^f' | while read t config file
    do getrfsfile.sh "rootfs/etc/apt/sources.list.d$file"
  done
  echo
  echo 'deb [trusted=yes] file:///usr/share/first-boot-setup/temp-repo/ ./'
) >"$tmp/rootfs/usr/share/first-boot-setup/temporary-local-repo.list"

# Do some stuff inside the chroot
(
  cp script/rootfs_setup.sh "$tmp/rootfs/usr/share/first-boot-setup/rootfs_setup.sh"
  chroot_qemu_static.sh "$tmp/rootfs/" /usr/share/first-boot-setup/rootfs_setup.sh
  rm "$tmp/rootfs/usr/share/first-boot-setup/rootfs_setup.sh"
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
