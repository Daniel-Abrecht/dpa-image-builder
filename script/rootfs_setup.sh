#!/bin/sh

set -ex

cd /

# Install kernel
dpkg -i /root/linux-image.deb /root/linux-libc.deb /root/linux-headers.deb
rm /root/linux-image.deb /root/linux-libc.deb /root/linux-headers.deb

## Update & download packages

# Use temporary apt config for temporary bootstrap sources
cat > /root/apt-tmp.conf <<EOF
Dir::Etc::sourcelist "/root/temporary-local-repo.list";
Dir::Etc::sourceparts "-";
APT::Get::List-Cleanup "0";
EOF
export APT_CONFIG=/root/apt-tmp.conf

# Use bootstrapping repos for this
cat >/root/temporary-local-repo.list <<EOF
deb $REPO $RELEASE          main
deb $REPO $RELEASE-updates  main
deb $REPO $RELEASE-security main
EOF

# Update package list, update everything, and clean apt cache (remove no longer needed packages)
apt-get update
apt-get -y dist-upgrade
apt-get clean

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
EOF

# Update package list of local repo
apt-get update
