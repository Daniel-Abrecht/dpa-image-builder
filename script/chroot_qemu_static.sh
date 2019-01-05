#!/bin/sh

if [ -z "$AARCH64_EXECUTABLE" ]
  then echo "Warning: AARCH64_EXECUTABLE is not set! (Note: This script is expected to be called by the make file)" >&2
fi

set -ex

export PATH='/root/helper/:/sbin:/usr/sbin:/bin:/usr/bin'

rootfs="$1"
shift

qemu_aarch64_static_binary="$(which qemu-aarch64-static qemu-aarch64 | head -n 1)"

cp "$qemu$qemu_aarch64_static_binary" "$rootfs$qemu_aarch64_static_binary" || true

if [ "$AARCH64_EXECUTABLE" = yes ]
then
  chroot "$rootfs" "$@"
else
  dpkg -x "$rootfs"/var/cache/apt/archives/libfakechroot*.deb "$rootfs"
  chroot "$rootfs" "$qemu_aarch64_static_binary" -E LD_PRELOAD=/usr/lib/aarch64-linux-gnu/fakechroot/libfakechroot.so -E FAKECHROOT_ELFLOADER="$qemu_aarch64_static_binary" /bin/sh -c "exec $*"
fi

rm -f "$rootfs$qemu_aarch64_static_binary"
