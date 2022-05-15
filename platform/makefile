include ../src/make-helper-functions.mk

all repo update-repo clean-repo clean-build: force
	make -C $(BUILDER_PLATFORM) $@

clean-build-all: force
	for BUILDER_PLATFORM in */; do $(MAKE) BUILDER_PLATFORM="$$BUILDER_PLATFORM" -C "$$BUILDER_PLATFORM" clean-build-all; done

%: always
	make -C $(BUILDER_PLATFORM) $@

force: ;
