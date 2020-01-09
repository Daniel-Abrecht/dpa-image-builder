#!/bin/sh

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

user=
while [ -z "$user" ]
  do user=$(dialog --no-cancel --inputbox "Please choose your username" 0 0 3>&1 1>&2 --output-fd 3)
done

useradd -U -m -s /bin/bash "$user"
setpw "$user"

usermod -a -G users "$user"
usermod -a -G audio "$user"
usermod -a -G video "$user"
usermod -a -G netdev "$user"
usermod -a -G cdrom "$user"
