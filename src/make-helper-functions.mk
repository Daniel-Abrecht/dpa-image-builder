
default_target: all

project_root := $(dir $(lastword $(MAKEFILE_LIST)))..

VARS_OLD := $(.VARIABLES)

ifeq ($(shell test -e "$(project_root)/config/userdefined.mk" && echo -n yes),yes)
include $(project_root)/config/userdefined.mk
endif

ifeq ($(shell test -e "$(project_root)/config/defaults.mk" && echo -n yes),yes)
include $(project_root)/config/defaults.mk
endif

ifeq ($(shell test -e "$(project_root)/config/userdefined.mk" && echo -n yes),yes)
include $(project_root)/config/userdefined.mk
endif

ifeq ($(shell test -e "$(project_root)/config/$(CONFIG).mk" && echo -n yes),yes)
include $(project_root)/config/$(CONFIG).mk
endif

ifeq ($(shell test -e "$(project_root)/config/userdefined.mk" && echo -n yes),yes)
include $(project_root)/config/userdefined.mk
endif

CONFIG_VARS = $(sort $(filter-out $(VARS_OLD) VARS_OLD,$(.VARIABLES)))
unexport VARS_OLD

CONF = userdefined

include $(project_root)/src/repositories.mk



%/.dir: # We don't care if the directory gets modified, only if it exists or not. Let's check a dummy file instead
	mkdir -p "$(dir $@)"
	touch "$@"

clean:
	! echo -n "Please use one of:\n * make clean-build\t# remove all build files\n * make clean-repo\t# remove the downloaded repos\n * make reset-repo\t# clean up all changes made to the repo & update it if possible\n * make clean-all\t# do all of the above\n * make reset # do all of the above, but keep the repos\n"

repo/%/.repo:
	branch="$(repo-branch@$(patsubst repo/%/.repo,%,$@))"; \
	source="$(repo-source@$(patsubst repo/%/.repo,%,$@))"; \
	git clone -b "$$branch" "$$source" "$(dir $@)"
	touch "$@"

repo@%:
	make repo/$(patsubst repo@%,%,$@)/.repo

clean-repo@%:
	rm -rf "repo/$(patsubst clean-repo@%,%,$@)"

reset-repo@%:
	set -e; \
	repo="repo/$(patsubst reset-repo@%,%,$@)"; \
	if [ -d "$$repo/.git" ]; \
	then \
	  cd "$$repo"; \
	  find -maxdepth 1 -not -name .git -not -name . -exec rm -rf {} \;; \
	  git pull || true; \
	  git reset --hard; \
	  touch .repo; \
	fi

config-list:
	@$(foreach VAR,$(CONFIG_VARS), echo "$(VAR)" = "$($(VAR))"; )

config-set@%:
	@ if [ -z "$(TO)" ]; \
	  then echo "Usage: config-set@variablename TO=new_value"; \
	  false; \
	fi
	@ V="$(patsubst config-set@%,%,$@)"; \
	sed -i "/^$$V[ ]*=/d" "$(project_root)/config/$(CONF).mk" 2>&-; \
	echo "$$V = \"$(TO)\"" >> $(project_root)/config/$(CONF).mk

config-unset@%:
	@ V="$(patsubst config-unset@%,%,$@)"; \
	sed -i "/^$$V[ ]*=/d" "$(project_root)/config/$(CONF).mk"

clean-all: clean-repo clean-build
reset: reset-repo clean-build
