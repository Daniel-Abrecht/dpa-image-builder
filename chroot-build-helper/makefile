include ../src/make-helper-functions.mk

# Genereting the build dependencies for debian packages to be built requires
# the repos of those packages to be checked out. Always cloning them
# isn't desirable though, and generating the additional dependencies
# can't be done in the real makefile only after the repos of the packages
# to build are to be rebuilt, because the dependencies have to be known already
# at that point.
#
# For this reason, this makefile exists, which passes through any target
# to the real one. Before it does so, it checks if building a debian package
# is a target using a helper script which dumps the makefile dependency db
# in a dry-run and then checks using this data which targets depend in some way
# on the ones specified to make. In that case, it uses another script to generate
# the make dependencies for all debian packages, and thus also checks out the
# repos of all packages to be built.

%: force
	if makefile=real-makefile list-dependent-targets.sh "$@" | grep -q '^bin/.*/.build$$'; \
	then \
	  tmpdep=$$(mktemp); \
	  cleanup(){ rm -f "$$tmpdep"; }; \
	  trap cleanup EXIT INT; \
	  make -f "../src/make-helper-functions.mk" TMP_TARGET_FILE="$$tmpdep" DEP_PREFIX="bin/$(DISTRO)/$(RELEASE)/" DEP_SUFFIX="/.build" generate_make_build_dependencies_for_debs; \
	fi; \
	$(MAKE) -f real-makefile GENERATED_DEPENDENCIES_FILE="$$tmpdep" "$@"

force: ;
