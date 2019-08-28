#!/bin/sh

if [ -z "$project_root" ]; then
  echo "Error: project_root is not set! This script has to be called from the makefile build env" >&2
  exit 1
fi

CH_SUB=1 unshare -m -- chroot_qemu_static-sub1.sh "$@"
