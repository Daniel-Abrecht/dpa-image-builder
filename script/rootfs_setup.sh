#!/bin/sh

set -ex

cd /

## Update & download packages

# Use temporary apt config for temporary bootstrap sources
cat > /root/apt-tmp.conf <<EOF
Dir::Etc::sourcelist "/root/temporary-local-repo.list";
Dir::Etc::sourceparts "-";
APT::Get::List-Cleanup "0";
APT::Get::AllowUnauthenticated "true";
Acquire::AllowInsecureRepositories "true";
Dpkg::Options:: "--force-confdef";
Dpkg::Options:: "--force-confold";
EOF
export APT_CONFIG=/root/apt-tmp.conf

# Use bootstrapping repos for this
cat >/root/temporary-local-repo.list <<EOF
deb $REPO $RELEASE          main
deb $REPO $RELEASE-updates  main
deb $REPO $RELEASE-security main

deb file:///root/temp-repo/ ./
EOF

(
  cd /root/temp-repo/
  dpkg-scanpackages -m . > Packages
  gzip -k Packages
  xz -k Packages
)

export DEBIAN_FRONTEND=noninteractive

# Update package list, update everything, install kernel & other custom packages and clean apt cache (remove no longer needed packages)
apt-get update
apt-get -y dist-upgrade
apt-get -y install $(grep 'Package: ' /root/temp-repo/Packages | sed 's/Package: //' | sort -u)
rm -rf /root/temp-repo/
apt-get clean

# Packages such as flash-kernel may have been installed & configured after linux-image, which may have caused some triggers of them not to be run
# Reconfigure linux-image to make sure flash-kernel & co. get invoked
# (Just running flash-kernel would probably suffice, too.)
dpkg-reconfigure $(dpkg-query -f '${db:Status-Abbrev} ${binary:Package}\n' -W linux-image* | grep '^ii' | head -n 1 | grep -o '[^ ]*$')

# download packages
(
  IFS=", "
  for package in $packages
  do
    apt-get -d -y install "$package"
  done
)

# Remove temporary list file again
rm /root/temporary-local-repo.list

# Move packages from apt cache to temporary repo
mkdir /root/temp-repo/
mv /var/cache/apt/archives/*.deb /root/temp-repo/

# Create package list for repo
(
  cd /root/temp-repo/
  dpkg-scanpackages -m . > Packages
  gzip -k Packages
  xz -k Packages
)

# Add new temporary local repo list
echo "deb file:///root/temp-repo/ ./" > /root/temporary-local-repo.list

# Create temporary apt config for temporary local repo
cat > /root/apt-tmp.conf <<EOF
Dir::Etc::sourcelist "/root/temporary-local-repo.list";
Dir::Etc::sourceparts "-";
APT::Get::List-Cleanup "0";
APT::Get::AllowUnauthenticated "true";
Acquire::AllowInsecureRepositories "true";
EOF

# Update package list of local repo
apt-get update
