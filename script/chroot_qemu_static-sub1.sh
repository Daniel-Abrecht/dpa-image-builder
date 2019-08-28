#!/bin/sh

if [ -z "$CH_SUB" ]; then
  echo "Error: Use chroot_qemu_static.sh instead" >&2
  exit 1
fi

rootfs="$1"
shift

# Only one user at a time allowed
( flock 9 || exit 1; (

cleanup(){
  set +e
  umount -lf "$rootfs"/sys
  umount -lf "$rootfs"/proc
  umount -lf "$rootfs"/dev
  rm -f "$rootfs"/usr/sbin/policy-rc.d
}
trap cleanup EXIT TERM INT

# Some checks & stuff
if [ -z "$AARCH64_EXECUTABLE" ]
  then echo "Warning: AARCH64_EXECUTABLE is not set! (Note: This script is expected to be called by the make file)" >&2
fi

set -ex

export PATH='/root/helper/:/sbin:/usr/sbin:/bin:/usr/bin'
export LANG=C LC_ALL=C

qemu_aarch64_static_binary="$(which qemu-aarch64-static qemu-aarch64 | head -n 1)"

cp "$qemu$qemu_aarch64_static_binary" "$rootfs$qemu_aarch64_static_binary" || true

mount --rbind /proc/ "$rootfs"/proc/
mount --rbind /dev/ "$rootfs"/dev/
mount --rbind /sys/ "$rootfs"/sys/

cat >"$rootfs"/usr/sbin/policy-rc.d <<EOF
#!/bin/sh
exit 101
EOF
chmod +x "$rootfs"/usr/sbin/policy-rc.d

# Enter the chroot
if [ "$AARCH64_EXECUTABLE" = yes ]
then
  chroot "$rootfs" "$@"
else
  dpkg -x "$rootfs"/var/cache/apt/archives/libfakechroot*.deb "$rootfs"
  chroot "$rootfs" "$qemu_aarch64_static_binary" -E LD_PRELOAD=/usr/lib/aarch64-linux-gnu/fakechroot/libfakechroot.so -E FAKECHROOT_ELFLOADER="$qemu_aarch64_static_binary" /bin/sh -c "exec $*"
fi

rm -f "$rootfs$qemu_aarch64_static_binary"
rm -f "$rootfs"/usr/sbin/policy-rc.d

) 9>&-; ) 9>"$rootfs/chroot_access_lock"
