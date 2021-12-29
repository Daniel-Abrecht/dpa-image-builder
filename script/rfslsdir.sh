#!/bin/sh

if [ -z "$project_root" ]; then
  echo "Error: project_root is not set! This script has to be called from the makefile build env" >&2
  exit 1
fi

set -e

if [ "$1" = "-r" ]; then recursive=1; shift; fi

if printf '%s' "$1" | grep -q "\(^\|/\)\.\.\(/\|$\)"
then
  echo "Traversal to parent directories not allowed"
  exit 1
fi

# Make sure the current working directory is correct
cd "$(dirname "$0")/../config/"

basepath="$(printf '%s' "$1" | sed 's|/\+|/|g;s|/\(\./\)\+|/|g;s|^\(\./\)\+||;s|/\.\?$||')"
  
findall(){
  local f="$(printf "$1" | sed 's/\.\(ignore\|rm\|in\)$//')"
  local rc=1
  local confdir=
  for dir in $CONFIG_PATH
    do for dir2 in $CONFIG_PATH
      do if [ "$dir/$basepath$f" = "$dir2" ]
        then return 1
      fi
    done
  done
  for dir in $(printf '%s\n' $CONFIG_PATH | tac)
  do
    if [ ! -h "$dir/$basepath$f" ] && [ -d "$dir/$basepath$f" ]
    then
      if [ $rc = 1 ]
        then printf "d\t-\t%s/\n" "$f"
      fi
      if [ "$2" = 1 ]
      then
        confdir="$dir/$basepath"
        for file in "$dir/$basepath$f/"*
        do
          relfile="$(printf "%s" "$file" | sed "s/^.\{${#confdir}\}//")"
          findall "$relfile" "$recursive" || true
        done
        rc=0
      fi
    else
      if [ -f "$dir/$basepath$f.ignore" ]
      then
        printf "i\t%s\t%s\n" "$dir" "$f"
        return 0
      elif [ -f "$dir/$basepath$f.rm" ]
      then
        printf "r\t%s\t%s\n" "$dir" "$f"
        return 0
      elif [ -f "$dir/$basepath$f.in" ]
      then
        printf "s\t%s\t%s\n" "$dir" "$f"
      elif [ -h "$dir/$basepath$f" ] || [ -f "$dir/$basepath$f" ]
      then
        printf "f\t%s\t%s\n" "$dir" "$f"
      fi
    fi
  done
  return $rc
}

# Meke sure default sorting is used
export LC_ALL=C

findall "" 1 | sort -u -k 3 | sed 's|/\+|/|g'
