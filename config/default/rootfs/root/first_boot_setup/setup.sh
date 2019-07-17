#!/bin/sh -e

cd /root/first_boot_setup/ || exit 1

export DEBCONF_FORCE_DIALOG=1
export APT_CONFIG=/root/first_boot_setup/apt-tmp.conf

setpw(){
  local pw=
  local confirm_pw=
  while [ -z "$pw" ] || [ "$pw" != "$confirm_pw" ]
  do
    pw="$(dialog --no-cancel --insecure --passwordbox "Please set the password for $1" 0 0 3>&1 1>&2 --output-fd 3)" || true
    [ -n "$pw" ] || continue
    confirm_pw="$(dialog --no-cancel --insecure --passwordbox "Please confirm the password" 0 0 3>&1 1>&2 --output-fd 3)" || true
  done
  printf '%s' "$1:$pw" | chpasswd
}

dpkg-reconfigure locales

setpw root

for script in pre_target_install/*
do
  [ -x "$script" ] || continue
  sh -x "$script"
done

# install remaining packages
apt-get update
apt-get -y install $(cat ./packages_to_install)

for script in post_target_install/*
do
  [ -x "$script" ] || continue
  sh -x "$script"
done

set +e

# clean apt cache
apt-get clean

# Remove first boot scripts
rm -r /root/first_boot_setup/

chvt 1
