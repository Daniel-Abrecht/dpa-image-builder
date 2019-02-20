#!/bin/sh

cleanup(){
  if [ -n "$urandom_PID" ]
  then
    kill $urandom_PID
    true <"$rootfs/dev/urandom"
    rm "$rootfs/dev/urandom"
  fi
  if [ -n "$zero_PID" ]
  then
    kill $zero_PID
    true <"$rootfs/dev/zero"
    rm "$rootfs/dev/zero"
  fi
}
trap cleanup EXIT TERM INT

# Some checks & stuff
if [ -z "$AARCH64_EXECUTABLE" ]
  then echo "Warning: AARCH64_EXECUTABLE is not set! (Note: This script is expected to be called by the make file)" >&2
fi

set -ex

export PATH='/root/helper/:/sbin:/usr/sbin:/bin:/usr/bin'
export LANG=C LC_ALL=C

rootfs="$1"
shift

qemu_aarch64_static_binary="$(which qemu-aarch64-static qemu-aarch64 | head -n 1)"

cp "$qemu$qemu_aarch64_static_binary" "$rootfs$qemu_aarch64_static_binary" || true


# Emulate some files in /dev/  if necessary
[ ! -e "$rootfs/dev/urandom" ]
has_no_urandom=$?

if [ "$has_no_urandom" = 0 ]
then
  mkfifo "$rootfs/dev/urandom"
  (
    set +ex
    while [ -e "$rootfs/dev/urandom" ]
      do dd bs=1 if=/dev/urandom of="$rootfs/dev/urandom"
    done
  ) & urandom_PID=$!
fi

[ ! -e "$rootfs/dev/zero" ]
has_no_zero=$?

if [ "$has_no_zero" = 0 ]
then
  mkfifo "$rootfs/dev/zero"
  (
    set +ex
    while [ -e "$rootfs/dev/zero" ]
      do dd bs=1 if=/dev/zero of="$rootfs/dev/zero"
    done
  ) & zero_PID=$!
fi


# Enter the chroot
if [ "$AARCH64_EXECUTABLE" = yes ]
then
  chroot "$rootfs" "$@"
else
  dpkg -x "$rootfs"/var/cache/apt/archives/libfakechroot*.deb "$rootfs"
  chroot "$rootfs" "$qemu_aarch64_static_binary" -E LD_PRELOAD=/usr/lib/aarch64-linux-gnu/fakechroot/libfakechroot.so -E FAKECHROOT_ELFLOADER="$qemu_aarch64_static_binary" /bin/sh -c "exec $*"
fi

rm -f "$rootfs$qemu_aarch64_static_binary"

exit 0
