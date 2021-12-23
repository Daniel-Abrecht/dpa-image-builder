#!/bin/sh

set -e

rootfs="$1"; shift

DEBOOTSTRAP_DIR="$X_DEBOOTSTRAP_DIR/usr/share/debootstrap/" uexec "$X_DEBOOTSTRAP_DIR/usr/sbin/debootstrap" --foreign --arch=arm64 "$@" "$RELEASE" "$rootfs" "$REPO" "$DEBOOTSTRAP_SCRIPT"
echo meow >"$rootfs/hostname" # Some things need a hostname, but we don't want to leak the hostname of the bootstrapping system
mkdir -p "$rootfs/root/helper"
echo '#!/bin/sh' >"$rootfs/root/helper/mknod" # Don't worry about this, on boot, the kernel mounts /dev as devtmpfs before calling init anyway
chmod +x "$rootfs/root/helper/"*
chns "$rootfs/" /debootstrap/debootstrap --second-stage
rm -r "$rootfs/root/helper"
