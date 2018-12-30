#!/bin/sh

# Note: This is only necessary if using binfmt_misc isn't wanted.
# With binfmt_misc, a simple `cp /usr/bin/qemu-aarch64-static "$rootfs"/usr/bin/qemu-aarch64-static; chroot "$rootfs" "$@"` would be sufficent.

set -ex

export PATH='/root/helper/:/sbin:/usr/sbin:/bin:/usr/bin'

rootfs=$1
shift

dpkg -x "$rootfs"/var/cache/apt/archives/libfakechroot*.deb "$rootfs"
cp /usr/bin/qemu-aarch64-static "$rootfs"/usr/bin/qemu-aarch64-static
chroot "$rootfs" /usr/bin/qemu-aarch64-static -E LD_PRELOAD=/usr/lib/aarch64-linux-gnu/fakechroot/libfakechroot.so -E FAKECHROOT_ELFLOADER=/usr/bin/qemu-aarch64-static /bin/sh -c "exec $*"
rm "$rootfs"/usr/bin/qemu-aarch64-static
