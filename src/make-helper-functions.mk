
project_root := $(dir $(lastword $(MAKEFILE_LIST)))..

include $(project_root)/src/repositories.mk

%/.dir: # We don't care if the directory gets modified, only if it exists or not. Let's check a dummy file instead
	mkdir -p "$(dir $@)"
	touch "$@"

clean:
	! echo -n "Please use one of:\n * make clean-build\t# remove all build files\n * make clean-repo\t# remove the downloaded repos\n * make reset-repo\t# clean up all changes made to the repo & update it if possible\n * make clean-all\t# do all of the above\n * make reset # do all of the above, but keep the repos\n"


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

clean-all: clean-repo clean-build
reset: reset-repo clean-build
