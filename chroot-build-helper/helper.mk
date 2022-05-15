PLATFORM_AGNOSTIC_TARGETS += build-env/%
PLATFORM_AGNOSTIC_TARGETS += $(project_root)/build-env/%
PLATFORM_AGNOSTIC_TARGETS += buildenv

$(info "$(MAKECMDGOALS)")

include ../src/make-helper-functions.mk
