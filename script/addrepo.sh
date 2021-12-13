#!/bin/sh

set -ex

[ -n "$REPO_DIR" ]
[ -n "$DISTRO" ]
[ -n "$RELEASE" ]
[ -n "$NEW_PKG_ORIGIN" ]

repodir="$REPO_DIR"

# Create repo / release if it doesn't exist yet
if [ ! -d "$repodir/dists/$DISTRO/$RELEASE" ]
  then dparepo "$repodir" "$DISTRO/$RELEASE" create "$NEW_PKG_ORIGIN" "$DISTRO $RELEASE $EXTRA_REPO_LABELS" "$DISTRO/$RELEASE" "Images built using the dpa-image-builder"
fi

# Add package
if [ -n "$1" ]
  then dparepo "$repodir" "$DISTRO/$RELEASE" add "$BUILDER_PLATFORM" "$1"
fi
