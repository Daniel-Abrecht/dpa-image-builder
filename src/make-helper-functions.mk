
# I don't like doing this, but dash removes environment variables which aren't named to it's liking
# I use some bash scripts anyway, and bash doesn't do such nonesense, so... yea, this'll use bash now too, sorry.
SHELL=/bin/bash

default_target: all

.SECONDARY:

project_root := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))..)
export project_root

define newline


endef

define include_config_if_exits
  ifeq ($(shell test -e "$(project_root)/config/$(1)" && echo -n yes),yes)
    include $(project_root)/config/$(1)
    ifeq ($(shell test -e "$(project_root)/config/user_config_override" && echo -n yes),yes)
      include $(project_root)/config/user_config_override
    endif
  endif
endef

VARS_OLD := $(subst %,,$(subst *,,$(.VARIABLES)))

ifeq ($(shell test -e "$(project_root)/config/user_config_override" && echo -n yes),yes)
include $(project_root)/config/user_config_override
endif

$(eval $(call include_config_if_exits,default/config))
$(foreach config,$(CONFIG_PATH),$(eval $(call include_config_if_exits,$(config)/config)))

ifdef REPO-$(DISTRO)
  REPO = $(REPO-$(DISTRO))
endif

ifdef REPO-$(DISTRO)-$(RELEASE)
  REPO = $(REPO-$(DISTRO)-$(RELEASE))
endif

ifdef CHROOT_REPO-$(DISTRO)
  CHROOT_REPO = $(CHROOT_REPO-$(DISTRO))
endif

ifdef CHROOT_REPO-$(DISTRO)-$(RELEASE)
  CHROOT_REPO = $(CHROOT_REPO-$(DISTRO)-$(RELEASE))
endif

CONFIG_VARS := $(sort $(filter-out $(VARS_OLD) VARS_OLD,$(subst %,,$(subst *,,$(.VARIABLES)))))
IMGSIZE := $(shell echo "$(IMGSIZE)" | sed 's/\s*//g')
export $(CONFIG_VARS)

CONF = user_config_override

X_DEBOOTSTRAP_DIR = $(project_root)/build/$(DISTRO)-$(RELEASE)/debootstrap_script/
DEBOOTSTRAP_SCRIPT = $(X_DEBOOTSTRAP_DIR)/usr/share/debootstrap/scripts/$(RELEASE)

PLATFORM_AGNOSTIC_TARGETS += config-set//% config-unset//% config-after-update//%
PLATFORM_AGNOSTIC_TARGETS += mirror//% chroot//% %/.dir
PLATFORM_AGNOSTIC_TARGETS += $(project_root)/build/$(DISTRO)-$(RELEASE)/%
PLATFORM_AGNOSTIC_TARGETS += build/$(DISTRO)-$(RELEASE)/%
PLATFORM_AGNOSTIC_TARGETS += $(project_root)/build/bin/%
PLATFORM_AGNOSTIC_TARGETS += build/bin/%
PLATFORM_AGNOSTIC_TARGETS += $(DEBOOTSTRAP_SCRIPT)
PLATFORM_AGNOSTIC_TARGETS += config-list
PLATFORM_AGNOSTIC_TARGETS += generate_make_build_dependencies_for_debs
PLATFORM_AGNOSTIC_TARGETS += clean-build-all

ifndef BUILDER_PLATFORM
ifneq (,$(MAKECMDGOALS))
ifeq (,$(filter-out $(PLATFORM_AGNOSTIC_TARGETS),$(MAKECMDGOALS)))
BUILDER_PLATFORM=none
endif
endif
endif

ifndef BUILDER_PLATFORM
KNOWN_BOARDS=$(shell basename -a "$(project_root)/config/default/"b-*/ | sed 's|^b-||')
$(error "$(newline)Please specify a board. Pass BOARD= to make, or set it in the config using `make config-set//BOARD TO=my-board`.$(newline)Availabe boards are: $(KNOWN_BOARDS)$(newline)")
endif

include $(project_root)/src/repositories.mk

export PATH := /helper/bin:$(project_root)/script/:/sbin:/usr/sbin:$(PATH):$(project_root)/build/bin:$(project_root)/bin

include $(project_root)/src/package_list.mk

export DEBIAN_FRONTEND=noninteractive

ifneq ($(BUILDER_PLATFORM),none)
include $(project_root)/platform/$(BUILDER_PLATFORM)/platform.mk
endif

export X_DEBOOTSTRAP_DIR
export DEBOOTSTRAP_SCRIPT

define repodir
repo/$(shell printf '%s\n' "$(repo-source@$(1))" | sed 's / ∕ g').git
endef


generate_make_build_dependencies_for_debs:
	export DEP_PREFIX=$(DEP_PREFIX); \
	export DEP_SUFFIX=$(DEP_SUFFIX); \
	if [ -n "$(TMP_TARGET_FILE)" ]; \
	  then generate_make_build_dependencies_for_debs.sh >"$(TMP_TARGET_FILE)"; \
	  else generate_make_build_dependencies_for_debs.sh; \
	fi

%/.dir:
	mkdir -p "$(dir $@)"
	touch "$@"

chroot//%:
	export PROMPT_COMMAND="export PS1='$@ (\u)> '"; \
	CHNS_INTERACTIVE=1 chns "$(realpath $(patsubst chroot//%,%,$@))" /bin/bash

clean:
	@! printf "Please use one of:\n * make clean-build\t# remove all files built for the target image (includes the image)\n * make clean-build-all\t# remove all files that have been built\n * make clean-repo\t# remove the downloaded repos\n * make update-repo\t# clean up all changes made to the repo & update it if possible\n * make clean-all\t# same as 'make clean-repo clean-build'\n * make clean-all-all\t# same as 'make clean-repo clean-build-all'\n * make reset\t\t# same as 'make update-repo clean-build'\n * make reset-all\t# same as 'make update-repo clean-build-all'\n"

repo/%.git:
	repo="$(shell echo "$(patsubst repo/%.git,%,$@)" | sed 's ∕ / g')"; \
	git clone --mirror "$$repo" "$@"

mirror//%:
	$(MAKE) "repo/$(shell echo "$(patsubst mirror//%,%,$@)" | sed 's / ∕ g').git"

repo//%:
	$(MAKE) "$(call repodir,$(patsubst repo//%,%,$@))"

clean-repo//%:
	rm -rf "$(call repodir,$(patsubst clean-repo//%,%,$@))"

update-repo//%:
	repo="$(call repodir,$(patsubst update-repo//%,%,$@))"; \
	if [ -d "$$repo" ]; then cd "$$repo" && git remote update && touch .; fi

config-list:
	@$(foreach VAR,$(CONFIG_VARS), echo "$(VAR)" = "$($(VAR))"; )

config-after-update//%:
	@ set -e; \
	case "$(patsubst config-after-update//%,%,$@)" in \
	  "IMGSIZE"    ) $(MAKE) clean-image ;; \
	  "REPO"       ) $(MAKE) clean-fs ;; \
	  "CHROOT_REPO") $(MAKE) clean-fs ;; \
	  "KERNEL_DTB" ) $(MAKE) clean-fs ;; \
	  "IMAGE_NAME" ) $(MAKE) clean-image ;; \
	  "repo-branch@"*) $(MAKE) "update-repo//$(patsubst config-after-update//repo-branch@%,%,$@)" ;; \
	  "repo-source@"*) $(MAKE) "update-repo//$(patsubst config-after-update//repo-source@%,%,$@)" FETCH_REQUIRED_TO_SUCCEED=true ;; \
	  "UBOOT_DTB" | "UBOOT_CONFIG_TARGET" | "repo-source@uboot" | "repo-branch@uboot") \
	    $(MAKE) -C "$(project_root)/platform/$(BUILDER_PLATFORM)/" clean-build \
	  ;; \
	  "KERNEL_CONFIG_TARGET" | "repo-source@linux" | "repo-branch@linux") \
	    $(MAKE) -C "$(project_root)/kernel/" clean-build \
	  ;; \
	esac

config-set//%:
	@ if [ -z "$(TO)" ]; \
	  then echo "Usage: config-set//variablename TO=new_value"; \
	  false; \
	fi
	V="$(patsubst config-set//%,%,$@)"; \
	sed -i "/^$$V[ ]*=/d" "$(project_root)/config/$(CONF)" 2>&-; \
	echo "$$V = $(TO)" >> $(project_root)/config/$(CONF)
	@ $(MAKE) --no-print-directory OLD_VALUE="$($(patsubst config-set//%,%,$@))" "config-after-update//$(patsubst config-set//%,%,$@)"

config-unset//%:
	V="$(patsubst config-unset//%,%,$@)"; \
	sed -i "/^$$V[ ]*=/d" "$(project_root)/config/$(CONF)"
	@ $(MAKE) --no-print-directory OLD_VALUE="$($(patsubst config-unset//%,%,$@))" "config-after-update//$(patsubst config-unset//%,%,$@)"

clean-all: clean-repo clean-build
clean-all-all: clean-repo clean-build-all
reset: update-repo clean-build
reset-all: update-repo clean-build-all

.PHONY: all repo update-repo clean-repo clean clean-all clean-all-all clean-build clean-build-all
