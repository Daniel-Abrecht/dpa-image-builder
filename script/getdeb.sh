#!/bin/sh -ex

dest="$(dirname "$1")/$(basename "$1" .deb).deb"
package="$(basename "$dest" .deb)"
package_details="$(deblookup.sh "$package")"
url="$REPO/$(printf '%s\n' "$package_details" | sed -n 's/^Filename: \(.*\)/\1/p')"

curl --fail -L "$url" -o "$dest"
