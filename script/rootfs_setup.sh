#!/bin/sh

if [ -z "$project_root" ]; then
  echo "Error: project_root is not set! This script has to be called from the makefile build env" >&2
  exit 1
fi

set -ex

cd /usr/share/first-boot-setup/

printf '%s\n' $PACKAGES_INSTALL_TARGET > "packages_to_install"
printf '%s\n' $PACKAGES_BOOTSTRAP_WORKAROUND > "dummy_packages_to_replace"

## Update & download packages

# Use temporary apt config for temporary bootstrap sources
cat > apt-tmp.conf <<EOF
Dir::Etc::sourcelist "/usr/share/first-boot-setup/temporary-local-repo.list";
Dir::Etc::sourceparts "-";
APT::Get::List-Cleanup "0";
APT::Get::AllowUnauthenticated "true";
Acquire::AllowInsecureRepositories "true";
Dpkg::Options:: "--force-confdef";
Dpkg::Options:: "--force-confold";
EOF
export APT_CONFIG=/usr/share/first-boot-setup/apt-tmp.conf

(
  cd temp-repo/
  dpkg-scanpackages -m . > Packages
  gzip -k Packages
  xz -k Packages
)

# run post_debootstrap scripts
for pdscript in post_debootstrap/*
do
  if [ -x "$pdscript" ]
    then "$pdscript"
  fi
done

# Update package list, update everything, install kernel & other custom packages and clean apt cache (remove no longer needed packages)
apt-get update
apt-get -y dist-upgrade
apt-get -y install $(grep 'Package: ' temp-repo/Packages | sed 's/Package: //' | sort -u | grep -v Auto-Built-debug-symbols | grep '^linux-')

# Install some other packages
apt-get -y install $PACKAGES_INSTALL_EARLY

# Packages such as flash-kernel have been installed & configured after linux-image, which may have caused some triggers of them not to be run
# Reconfigure linux-image to make sure flash-kernel & co. get invoked
# (Just running flash-kernel would probably suffice, too.)
dpkg-reconfigure $(dpkg-query -f '${db:Status-Abbrev} ${binary:Package}\n' -W linux-image* | grep '^ii' | head -n 1 | grep -o '[^ ]*$')

for script in post_early_install/*
do
  [ -x "$script" ] || continue
  sh -x "$script"
done

apt-get clean

# download packages
for package in $PACKAGES_INSTALL_TARGET $PACKAGES_TO_DOWNLOAD
  do apt-get -d -y install "$package"
done

for package in $PACKAGES_BOOTSTRAP_WORKAROUND
  do apt-get -d -y install -t "$RELEASE" "$package"
done

rm -rf temp-repo/

# Remove temporary list file again
rm temporary-local-repo.list

# Move packages from apt cache to temporary repo
mkdir temp-repo/
mv /var/cache/apt/archives/*.deb temp-repo/ || true

# Create package list for repo
(
  cd temp-repo/
  dpkg-scanpackages -m . > Packages
  gzip -k Packages
  xz -k Packages
)

# Add new temporary local repo list
echo "deb file:///usr/share/first-boot-setup/temp-repo/ ./" > temporary-local-repo.list

# Create temporary apt config for temporary local repo
cat > apt-tmp.conf <<EOF
Dir::Etc::sourcelist "/usr/share/first-boot-setup/temporary-local-repo.list";
Dir::Etc::sourceparts "-";
APT::Get::List-Cleanup "0";
APT::Get::AllowUnauthenticated "true";
Acquire::AllowInsecureRepositories "true";
EOF

# Update package list of local repo
apt-get update

# In case the C.UTF-8 locale wasn't generated yet. Usually not that important though
locale-gen || true
