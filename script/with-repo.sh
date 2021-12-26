#!/bin/bash

if [ -z "$project_root" ]; then
  echo "Error: project_root is not set! This script has to be called from the makefile build env" >&2
  exit 1
fi

mkdir -p "$project_root/build/repo/"

unshare -mr /bin/bash -ex -c '
cleanup(){ umount "$project_root/build/repo/"; }
trap cleanup EXIT TERM INT
mount -t tmpfs none "$project_root/build/repo/"
clone_repo(){
  name="$1"
  repo_branch="$(printenv -- "repo-branch@$name")"
  repo_source="$(printenv -- "repo-source@$name")"
  gitrepo="$project_root/repo/$(sed "s / ∕ g" <<<"$repo_source").git"
  git clone --shared -b "$repo_branch" "$gitrepo" "$repodir/$name"
}
export repodir="$project_root/build/repo"
while IFS=, read name; do clone_repo "$name"; done <<<"$1"
shift
read _ uid _ </proc/self/uid_map
read _ gid _ </proc/self/gid_map
unshare --map-user="$uid" --map-group="$gid" -- "$@"
' -- "$@"
