#!/bin/bash

if [ -z "$project_root" ]; then
  echo "Error: project_root is not set! This script has to be called from the makefile build env" >&2
  exit 1
fi

mkdir -p "$project_root/build/repo/"

# Note: tmpfs size is set to 50% of ram, including swap.
# Default is 50% without swap, but that may not be enough on devices with only 4GB ram or so.
# On those devices, it's also possible to set KEEP_BUILD_REPO, but that's slower and leaves the repo directories behind. THat can sometimes be useful too, though. 

unshare -mr /bin/bash -ex -c '
cleanup(){ umount "$project_root/build/repo/"; }
trap cleanup EXIT TERM INT
if [ -z "$KEEP_BUILD_REPO" ]
then
  size=$(($(free -tm | sed -n "s/^Total:[ \t]*\([0-9]\+\).*/\1/p") / 2))
  mount -t tmpfs -o size="$size"m none "$project_root/build/repo/"
fi
clone_repo(){
  name="$1"
  repo_branch="$(printenv -- "repo-branch@$name")"
  repo_source="$(printenv -- "repo-source@$name")"
  gitrepo="$project_root/repo/$(sed "s / ∕ g" <<<"$repo_source").git"
  git clone --shared -n "$gitrepo" "$repodir/$name"
  ( cd "$repodir/$name"; git checkout "$repo_branch"; )
}
export repodir="$(mktemp -d -p "$project_root/build/repo" "repo.XXXXXXXXXX")"
while IFS=, read name; do clone_repo "$name"; done <<<"$1"
shift
read _ uid _ </proc/self/uid_map
read _ gid _ </proc/self/gid_map
unshare --map-user="$uid" --map-group="$gid" -- "$@"
' -- "$@"
