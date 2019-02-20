include ../src/make-helper-functions.mk

CURDIR=$(realpath .)

TARGETS = deb-flash-kernel

all: $(addprefix build@,$(TARGETS))

repo: \
  repo/flash-kernel/.repo

build@%: bin/%/.build
	@true

build-env/$(RELEASE): build-env/.dir
	mkdir -p "$@.tmp"
	$(SETUPBUILDENV) uexec rm -rf "$(CURDIR)/$@.tmp"
	$(SETUPBUILDENV) uexec --allow-setgroups debootstrap --foreign --arch=arm64 --include='build-essential,dh-make,debhelper,devscripts,fakeroot' "$(RELEASE)" "$(CURDIR)/$@.tmp" "$(REPO)"
	mkdir -p "$@.tmp/root/helper"
	echo '#!/bin/sh' >"$@.tmp/root/helper/mknod"
	echo '#!/bin/sh' >"$@.tmp/root/helper/mount"
	touch "$@.tmp/dev/null"
	chmod 666 "$@.tmp/dev/null"
	chmod +x "$@.tmp/root/helper/mknod" "$@.tmp/root/helper/mount"
	$(SETUPBUILDENV) uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/$@.tmp" /debootstrap/debootstrap --second-stage
	printf "deb %s %s main\ndeb-src %s %s main" "$(REPO)" "$(RELEASE)" "$(REPO)" "$(RELEASE)" >"$@.tmp/etc/apt/sources.list"
	mv "$@.tmp" "$@"

build-env/$(RELEASE)/root/%/src/.source: repo/%/.repo build-env/$(RELEASE)
	mkdir -p "$(dir $(dir $(dir $@)))"
	rm -rf "$(dir $(dir $@))"
	cp -r "$(dir $<)" "$(dir $@)"
	touch "$@"

bin/deb-%/.build: build-env/$(RELEASE)/root/%/src/.source
	find "$(<:%/src/.source=%)/" -maxdepth 1 -type f -delete
	$(SETUPBUILDENV) uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/build-env/$(RELEASE)" sh -c "cd /root/$(notdir $(<:build-env/$(RELEASE)/root/%/src/.source=%))/src/; apt-get update; apt-get -y build-dep .; debuild -uc -us"
	mkdir -p "$(dir $@)"
	cp "$(<:%/src/.source=%)"/*.deb "$(dir $@)"/
	touch "$@"

clean-repo: clean-repo@flash-kernel
reset-repo: reset-repo@flash-kernel

clean-build:
	$(SETUPBUILDENV) uexec rm -rf "$(CURDIR)/build-env/"
	rm -rf bin/
