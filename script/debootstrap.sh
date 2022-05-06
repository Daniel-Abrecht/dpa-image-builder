#!/bin/sh

if [ -z "$project_root" ]; then
  echo "Error: project_root is not set! This script has to be called from the makefile build env" >&2
  exit 1
fi

set -ex

# Make sure the current working directory is correct
cd "$(dirname "$0")/.."
base="$PWD"
tmp="$base/build/$IMAGE_NAME/"

exec 9<"$tmp"
if ! flock -n 9
then
  echo "It seams the build dir is still in use my another process. Refusing to proceed" >&2
  exit 1
fi

# Remove old files from previous runs
uexec rm -rf "$tmp/rootfs"

# Create temporary directories
mkdir -p "$tmp/rootfs"

sanitize_pkg_list(){
  sed 's/#.*//' | tr '\n' ',' | sed 's/\(,\|\s\)\+/,/g' | sed 's/^,\+\|,\+$//g'
}

mkdir -p "$tmp/rootfs/usr/share/first-boot-setup/post_debootstrap/"
# TODO: copy scripts

if [ -n "$PACKAGES_INSTALL_DEBOOTSTRAP" ]; then debootstrap_include="--include=$(printf "%s" "$PACKAGES_INSTALL_DEBOOTSTRAP" | tr ' ' ',')"; fi

# Create usable first-stage rootfs
debootstrap-base.sh "$tmp/rootfs" $debootstrap_include

mkdir -p "$tmp/rootfs/usr/share/first-boot-setup/temp-repo/"
cp "kernel/$KERNEL_CONFIG_TARGET/bin/"linux-*.deb "$tmp/rootfs/usr/share/first-boot-setup/temp-repo/" || true
rm -f "$tmp/rootfs/usr/share/first-boot-setup/temp-repo/"linux-*dbg*.deb

for deb in chroot-build-helper/bin/"$BUILDER_PLATFORM"/"$DISTRO"/"$RELEASE"/*/*.deb
do
  if [ -f "$deb" ]
    then cp "$deb" "$tmp/rootfs/usr/share/first-boot-setup/temp-repo/"
  fi
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
  chns "$tmp/rootfs/" /usr/share/first-boot-setup/rootfs_setup.sh
  rm "$tmp/rootfs/usr/share/first-boot-setup/rootfs_setup.sh"
)

# Move rootfs and bootfs to signal they're done
rm -rf "$tmp/root.fs"
touch -c "$tmp/rootfs"
mv "$tmp/rootfs" "$tmp/root.fs"
