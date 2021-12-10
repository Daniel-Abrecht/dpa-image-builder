include ../src/make-helper-functions.mk

all repo reset-repo clean-repo clean-build clean-build-all: force
	make -C $(BUILDER_PLATFORM) $@

%: always
	make -C $(BUILDER_PLATFORM) $@

force: ;
