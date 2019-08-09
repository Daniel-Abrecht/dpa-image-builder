#!/bin/sh

if [ -n "$dir" ]
  then dir="-C $dir"
fi

if [ -n "$makefile" ]
  then makefile="-f $makefile"
fi

alldeps="$(make $makefile $dir -pn $target | grep '^[^ #:]*[^ #]*:')"

#alldeps="$(
#  make $makefile $dir -pn $target |
#  tr '\n' '\1' |
#  sed 's/\x01\x01/\n\n/g' |
#  grep -v 'Not a target:' |
#  tr '\1' '\n' |
#  grep -v '^\s' |
#  grep '^[^#:]*:' |
#  sed 's/::/:/'
#)"

LF='
'
result=

find_true_deps(){
  dep="$1"
  if printf '%s\n' "$result" | grep -q "$dep"; then
    return 0
  fi
  printf '%s\n' "$dep"
  deps="$(printf '%s\n' "$alldeps" | sed -n 's|^\(.\+\s\+\)\?'"$dep"'\(\s\+.\+\)\?\s*:\(.*\)|\3|p' | sed 's/\s/\n/' | grep -v '^$')"
  result="$result$LF$dep"
  for d in $deps
    do find_true_deps "$d"
  done
  return 0
}

find_true_deps "$1" | sort -u
