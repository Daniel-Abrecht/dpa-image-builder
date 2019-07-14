#!/bin/bash

if [ -z "project_root" ]; then
  echo "Error: project_root is not set! This script has to be called from the makefile build env" >&2
  exit 1
fi

for package in $PACKAGES_TO_BUILD
do
  bulddeps="$(tr '\n' '\1' <"repo/$package/debian/control" |
    grep -o "$(printf '\(^\|\1\)Build-Depends:[^\1]*\(\1\\s\+[^\1]*\)*')" |
    tr '\1\n' '  ' | sed 's/ Build-Depends: //' |
    sed 's/([^)]*)//g;s/\(\,\|\s\)\+/ /g')"
  for dep in $bulddeps
  do
    for repo in $PACKAGES_TO_BUILD
    do
      debs="$(grep '^Package: \|^Provides: ' "repo/$repo/debian/control" | sed 's/^Package: //;s/Provides: //')"
      for deb in $debs
      do
        if [ "$dep" = "$deb" ]
        then
          echo "$DEP_PREFIX$package$DEP_SUFFIX: $DEP_PREFIX$repo$DEP_SUFFIX"
        fi
      done
    done
  done
done
