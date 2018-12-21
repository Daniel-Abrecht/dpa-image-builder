
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

ifeq ($(shell test -e "$(project_root)/config/board-$(BOARD).mk" && echo -n yes),yes)
include $(project_root)/config/board-$(BOARD).mk
endif

ifeq ($(shell test -e "$(project_root)/config/userdefined.mk" && echo -n yes),yes)
include $(project_root)/config/userdefined.mk
endif

CONFIG_VARS := $(sort $(filter-out $(VARS_OLD) VARS_OLD,$(.VARIABLES)))
IMGSIZE := $(shell echo "$(IMGSIZE)" | sed 's/\s*//g')
export $(CONFIG_VARS)

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
	source="$(repo-source@$(patsubst reset-repo@%,%,$@))"; \
	branch="$(repo-branch@$(patsubst reset-repo@%,%,$@))"; \
	if [ -d "$$repo/.git" ]; \
	then \
	  cd "$$repo"; \
	  find -maxdepth 1 -not -name .git -not -name . -exec rm -rf {} \;; \
	  git remote set-url origin "$$source"; \
	  git fetch || [ -z "$(FETCH_REQUIRED_TO_SUCCEED)" ]; \
	  git checkout "$$branch" >/dev/null; \
	  git reset --hard; \
	  touch .repo; \
	fi

config-list:
	@$(foreach VAR,$(CONFIG_VARS), echo "$(VAR)" = "$($(VAR))"; )

config-after-update@%:
	@ set -e; \
	case "$(patsubst config-after-update@%,%,$@)" in \
	  "IMGSIZE"    ) $(MAKE) clean-image ;; \
	  "REPO"       ) $(MAKE) clean-fs ;; \
	  "CHROOT_REPO") $(MAKE) clean-fs ;; \
	  "KERNEL_DTB" ) $(MAKE) clean-fs ;; \
	  "IMAGE_NAME" ) $(MAKE) clean-image ;; \
	  "BOARD"      ) \
	    for V in $$( ( \
	      grep -o '^[a-zA-Z0-9_@-]*' "$(project_root)/config/board-$(BOARD).mk"; \
	      grep -o '^[a-zA-Z0-9_@-]*' "$(project_root)/config/board-$(OLD_VALUE).mk" \
	    ) | sort -u; ); \
	    do \
	    $(MAKE) "config-after-update@$$V"; \
	    done; \
	  ;; \
	  "repo-branch@"*) $(MAKE) "reset-repo@$(patsubst config-after-update@repo-branch@%,%,$@)" ;; \
	  "repo-source@"*) $(MAKE) "reset-repo@$(patsubst config-after-update@repo-source@%,%,$@)" FETCH_REQUIRED_TO_SUCCEED=true ;; \
	  "UBOOT_DTB" | "UBOOT_CONFIG_TARGET" | "repo-source@uboot" | "repo-branch@uboot") \
	    $(MAKE) -C "$(project_root)/uboot/" clean-build \
	  ;; \
	  "KERNEL_CONFIG_TARGET" | "repo-source@linux" | "repo-branch@linux") \
	    $(MAKE) -C "$(project_root)/kernel/" clean-build \
	  ;; \
	esac

config-pre-set-check@%:
	@case "$(patsubst config-pre-set-check@%,%,$@)" in \
	  "BOARD") \
	     if [ ! -f "$(project_root)/config/board-$(TO).mk" ]; then \
	       echo "There is no config/board-$(TO).mk config file." >&2; \
	       false; \
	     fi; \
	   ;; \
	esac

config-set@%: config-pre-set-check@%
	@ if [ -z "$(TO)" ]; \
	  then echo "Usage: config-set@variablename TO=new_value"; \
	  false; \
	fi
	V="$(patsubst config-set@%,%,$@)"; \
	sed -i "/^$$V[ ]*=/d" "$(project_root)/config/$(CONF).mk" 2>&-; \
	echo "$$V = $(TO)" >> $(project_root)/config/$(CONF).mk
	@ $(MAKE) --no-print-directory OLD_VALUE="$($(patsubst config-set@%,%,$@))" "config-after-update@$(patsubst config-set@%,%,$@)"

config-unset@%:
	V="$(patsubst config-unset@%,%,$@)"; \
	sed -i "/^$$V[ ]*=/d" "$(project_root)/config/$(CONF).mk"
	@ $(MAKE) --no-print-directory OLD_VALUE="$($(patsubst config-unset@%,%,$@))" "config-after-update@$(patsubst config-unset@%,%,$@)"

clean-all: clean-repo clean-build
reset: reset-repo clean-build
