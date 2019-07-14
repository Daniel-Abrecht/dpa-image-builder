#!/bin/sh

if [ -z "project_root" ]; then
  echo "Error: project_root is not set! This script has to be called from the makefile build env" >&2
  exit 1
fi

set -e

if [ $# != 1 ]
then
  echo "Usage: $0 file" 2>&1
  exit 1
fi

# Make sure the current working directory is correct
cd "$(dirname "$0")/../config/"

find_path(){
  for dir in $(printf '%s\n' $CONFIG_PATH | tac)
  do
    for suffix in "" .in .ignore .rm
    do [ -f "./$dir/$1$suffix" ] || continue
      printf "%s" "./$dir/$1$suffix"
      return 0
    done
  done
  return 1
}

if ! source="$(find_path "$1")"
  then exit 1
fi

case "$source" in
  *.ignore|*.rm) exit 1 ;;
  *.in) sed 's/\$\$/\x1/g' <"$source" | envsubst | sed 's/\x1/\$/g' ;;
  *) cat "$source" ;;
esac

exit 0
