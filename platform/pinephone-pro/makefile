include ../../src/make-helper-functions.mk

PLATFORM_COMPONENTS=$(dir $(wildcard */makefile))

all repo clean-repo reset-repo clean-build clean-build-all:
	for dir in $(PLATFORM_COMPONENTS); do $(MAKE) -C "$$dir" "$@"; done
