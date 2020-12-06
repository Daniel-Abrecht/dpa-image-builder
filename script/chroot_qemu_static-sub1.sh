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

set -ex

export PATH='/root/helper/:/sbin:/usr/sbin:/bin:/usr/bin'
export LANG=C LC_ALL=C

mount --rbind /proc/ "$rootfs"/proc/
mount --rbind /dev/ "$rootfs"/dev/
mount --rbind /sys/ "$rootfs"/sys/

cat >"$rootfs"/usr/sbin/policy-rc.d <<EOF
#!/bin/sh
exit 101
EOF
chmod +x "$rootfs"/usr/sbin/policy-rc.d

chroot "$rootfs" "$@"

) 9>&-; ) 9>"$rootfs/.chroot_access_lock"
