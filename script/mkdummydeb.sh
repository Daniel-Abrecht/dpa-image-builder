#!/bin/sh -x

[ -n "$1" ] || exit 1

provides="$(basename "$1" .deb)"
file="$provides.deb"
name="$(printf '%s\n' "$provides" | grep -o '^[^,]*')"
cd "$(dirname "$1")"

version="$2"

if [ -z "$2" ]
  then version=99
fi

equivs-build - <<EOF
Section: misc
Priority: optional
Standards-Version: 3.9.2

Package: $name-dummy
Version: $version
Provides: $provides (= $version)
Architecture: all
Description: Dummy $name package. It probably caused problems in the changeroot.
EOF

mv "$name-dummy_${version}_all.deb" "$file"
