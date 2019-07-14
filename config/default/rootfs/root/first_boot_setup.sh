#!/bin/sh

set -ex

export DEBCONF_FORCE_DIALOG=1
export APT_CONFIG=/root/apt-tmp.conf

# install remaining packages
apt-get update
apt-get -y install $(cat /root/packages_to_install)
dpkg-reconfigure locales

# set root password
echo "Please set the root password"
while ! passwd; do true; done

set +e

# clean apt cache
apt-get clean

# Remove temporary repo
rm /root/temporary-local-repo.list
rm "$APT_CONFIG"
rm -r /root/temp-repo/
unset APT_CONFIG

# Remove this script
rm "$0"

chvt 1
