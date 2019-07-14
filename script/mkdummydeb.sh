#!/bin/sh -x

[ -n "$1" ] || exit 1

name="$(basename "$1" .deb)"
cd "$(dirname "$1")"

version=$2

if [ -z "$2" ]
  then version=99
fi

equivs-build - <<EOF
Section: misc
Priority: optional
Standards-Version: 3.9.2

Package: $name-dummy
Version: $version
Provides: $name
Architecture: all
Description: Dummy $name package. It probably caused problems in the changeroot.
EOF

mv "$name-dummy_${version}_all.deb" "$name.deb"
