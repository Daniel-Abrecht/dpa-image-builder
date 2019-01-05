#!/bin/sh

if [ -z "$AARCH64_EXECUTABLE" ]
  then echo "Warning: AARCH64_EXECUTABLE is not set! (Note: This script is expected to be called by the make file)" >&2
fi

set -ex

export PATH='/root/helper/:/sbin:/usr/sbin:/bin:/usr/bin'

rootfs="$1"
shift

cp /usr/bin/qemu-aarch64-static "$rootfs"/usr/bin/qemu-aarch64-static || true

if [ "$AARCH64_EXECUTABLE" = yes ]
then
  chroot "$rootfs" "$@"
else
  dpkg -x "$rootfs"/var/cache/apt/archives/libfakechroot*.deb "$rootfs"
  chroot "$rootfs" /usr/bin/qemu-aarch64-static -E LD_PRELOAD=/usr/lib/aarch64-linux-gnu/fakechroot/libfakechroot.so -E FAKECHROOT_ELFLOADER=/usr/bin/qemu-aarch64-static /bin/sh -c "exec $*"
fi

rm -f "$rootfs"/usr/bin/qemu-aarch64-static
