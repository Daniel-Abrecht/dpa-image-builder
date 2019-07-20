#!/bin/sh -e

if [ -z "$ARCH" ]
  then ARCH=arm64
fi

package="$1"
suite="$2"

if [ -z "$package" ]
then
  echo "Usage: $0 package [suite]"
  exit 1
fi

if [ -z "$suite" ]
  then suite=main
fi

url="$REPO/dists/$RELEASE/$suite/binary-$ARCH/"
{
  if curl -L --fail --silent "$url"Packages; then true
  else curl -L --fail --silent "$url"Packages.gz | gzip -d; fi
} | awk '/Package: '"$package"'/,/^$/{print $0; if($0 ~ /^$/) exit }'
