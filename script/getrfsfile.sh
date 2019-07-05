#!/bin/sh

set -e

if [ $# != 1 ]
then
  echo "Usage: $0 file" 2>&1
  exit 1
fi

# Make sure the current working directory is correct
cd "$(dirname "$0")/../rootfs_custom_files/"

file="$1"
if   [ -f "$file.in::$DISTRO-$RELEASE" ]
  then source="$file.in::$DISTRO-$RELEASE"
elif [ -f "$file::$DISTRO-$RELEASE" ]
  then source="$file::$DISTRO-$RELEASE"
elif [ -f "$file.in::$DISTRO" ]
  then source="$file.in::$DISTRO"
elif [ -f "$file::$DISTRO" ]
  then source="$file::$DISTRO"
elif [ -f "$file.in" ]
  then source="$file.in"
elif [ -f "$file" ]
  then source="$file"
  else exit 1
fi
file="$(printf "%s" "$source" | sed 's|::[^/]*$||')"

case "$file" in
  *.in) sed 's/\$\$/\x1/g' <"$source" | envsubst | sed 's/\x1/\$/g' ;;
  *) cat "$source" ;;
esac
