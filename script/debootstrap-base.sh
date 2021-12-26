#!/bin/sh

set -e

rootfs="$(realpath "$1")"; shift

# Debootstrap uses wget, and for unknown reasons, it decides to clutter the working dorectory with wget-log files.
# Do to keep the build dir clean, change the cwd
cd /tmp/

DEBOOTSTRAP_DIR="$X_DEBOOTSTRAP_DIR/usr/share/debootstrap/" uexec "$X_DEBOOTSTRAP_DIR/usr/sbin/debootstrap" --foreign --arch=arm64 "$@" "$RELEASE" "$rootfs" "$REPO" "$DEBOOTSTRAP_SCRIPT"
echo meow >"$rootfs/hostname" # Some things need a hostname, but we don't want to leak the hostname of the bootstrapping system
mkdir -p "$rootfs/root/helper"
echo '#!/bin/sh' >"$rootfs/root/helper/mknod" # Don't worry about this, on boot, the kernel mounts /dev as devtmpfs before calling init anyway
chmod +x "$rootfs/root/helper/"*
chns "$rootfs/" /debootstrap/debootstrap --second-stage
rm -r "$rootfs/root/helper"
