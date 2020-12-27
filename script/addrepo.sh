#!/bin/sh

set -ex

[ -n "$1" ]
[ -n "$REPO_DIR" ]
[ -n "$DISTRO" ]
[ -n "$RELEASE" ]
[ -n "$NEW_PKG_ORIGIN" ]
[ -n "$NEW_PKG_COMPONENT" ]
[ -n "$NEW_PKG_KEY" ]

outdir="$REPO_DIR"
dbdir="$outdir/db/$DISTRO-$RELEASE"
repodir="$outdir/repo/$DISTRO-$RELEASE"

mkdir -p "$dbdir/conf" "$repodir"

cat >"$dbdir/conf/distributions" <<EOF
Origin: $NEW_PKG_ORIGIN
Label: librem5 $DISTRO $RELEASE
Codename: $DISTRO-$RELEASE
Architectures: arm64
Components: $NEW_PKG_COMPONENT
Description: Automatically built packages for the librem5
SignWith: $NEW_PKG_KEY

EOF

sed -n '/^Files:$/ { :s; n; s/^ \([^ ]\+ \)\+\([^ ]\+\)$/\2/p; b s }' <"$1" |
while read deb
  do reprepro -Vb "$dbdir" --outdir "$repodir" remove "$DISTRO-$RELEASE" "$(dpkg-deb -f "$deb" Package)" || true
done

reprepro -Vb "$dbdir" --ignore=wrongdistribution -T dsc --outdir "$repodir" include "$DISTRO-$RELEASE" "$1" || true
reprepro -Vb "$dbdir" --ignore=wrongdistribution -T deb --outdir "$repodir" include "$DISTRO-$RELEASE" "$1"
