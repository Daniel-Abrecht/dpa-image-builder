define parse_package_list
$(shell \
  packages="$$(for list in $(CONFIG_PATH);
    do
      cat "$(project_root)/config/$$list/$(1)" 2>/dev/null || true;
      cat "$(project_root)/config/$$list/$(1)/"* 2>/dev/null || true;
    done | sort -u | sed 's/#.*//' | tr '\n' ' ' | sed 's/\s\+/ /g' | sed 's/^\s\+\|\s\+$$//g';
  )";
  for ignore in $$(printf "%s\n" $$packages | grep '^!' | sed 's/^!//g');
    do packages=$$(printf '%s\n' $$packages | grep -v "$$ignore");
  done;
  printf "%s\n" "$$packages" | grep -v '^!'
)
endef

PACKAGES_INSTALL_DEBOOTSTRAP  = $(call parse_package_list,install_debootstrap)
PACKAGES_INSTALL_EARLY        = $(call parse_package_list,install_early)
PACKAGES_INSTALL_TARGET       = $(call parse_package_list,install_target)
PACKAGES_TO_DOWNLOAD          = $(call parse_package_list,download)
PACKAGES_TO_BUILD             = $(call parse_package_list,build)
PACKAGES_BOOTSTRAP_WORKAROUND = $(call parse_package_list,defer_installation_of_problemetic_package)

repo-schema = $(shell printf '%s' "$(REPO)" | grep -o '^[^:]*')
ch-repo-schema = $(shell printf '%s' "$(CHROOT_REPO)" | grep -o '^[^:]*')

ifeq ($(shell [ "$(repo-schema)" = https ] || [ "$(ch-repo-schema)" = https ]; printf $$?),0)
  PACKAGES_INSTALL_DEBOOTSTRAP+=apt-transport-https
endif

ifeq ($(shell printf "$(repo-schema)"$$'\n'"$(ch-repo-schema)" | grep -q '^tor'; printf $$?),0)
  PACKAGES_INSTALL_DEBOOTSTRAP+=apt-transport-tor
endif

ifeq ($(shell [ "$(repo-schema)" = spacewalk ] || [ "$(ch-repo-schema)" = spacewalk ]; printf $$?),0)
  PACKAGES_INSTALL_DEBOOTSTRAP+=apt-transport-spacewalk
endif

export PACKAGES_INSTALL_DEBOOTSTRAP
export PACKAGES_INSTALL_EARLY
export PACKAGES_INSTALL_TARGET
export PACKAGES_TO_DOWNLOAD
export PACKAGES_TO_BUILD
export PACKAGES_BOOTSTRAP_WORKAROUND
