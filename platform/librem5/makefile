include ../../src/make-helper-functions.mk

L5_PLATFORM_COMPONENTS=$(dir $(wildcard */makefile))

all repo clean-repo update-repo clean-build clean-build-all:
	for dir in $(L5_PLATFORM_COMPONENTS); do $(MAKE) -C "$$dir" "$@"; done
