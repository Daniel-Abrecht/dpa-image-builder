include ../src/make-helper-functions.mk

CURDIR=$(realpath .)

TARGETS += deb-flash-kernel
TARGETS += deb-consolation
TARGETS += deb-libttymultiplex
TARGETS += deb-console-keyboard-basic
TARGETS += deb-console-keyboard-multiplexer

TARGETS += $(CROSSBUILD_SOURCE_PACKAGES)

# Packages using seccomp will hang qemu-user, so let's replace them
CHROOT_DUMMY_PACKAGES += man-db

CHROOT_DUMMY_PACKAGES_FILES = $(addprefix dummy-packages/,$(addsuffix -dummy_99_all.deb,$(CHROOT_DUMMY_PACKAGES)))

all: $(addprefix build@,$(TARGETS))

deb-console-keyboard-multiplexer: deb-libttymultiplex deb-console-keyboard-basic

repo: \
  repo/flash-kernel/.repo

build@%: bin/$(RELEASE)/%/.build
	@true

dummy-packages/%-dummy_99_all.deb: dummy-packages/%
	cd "$(dir $<)"; equivs-build "$(notdir $<)"

build-env/$(RELEASE): build-env/.dir $(CHROOT_DUMMY_PACKAGES_FILES)
	mkdir -p "$@.tmp"
	$(SETUPBUILDENV) uexec rm -rf "$(CURDIR)/$@.tmp"
	$(SETUPBUILDENV) uexec --allow-setgroups debootstrap --foreign --arch=arm64 "$(RELEASE)" "$(CURDIR)/$@.tmp" "$(REPO)"
	mkdir -p "$@.tmp/root/helper" "$@.tmp/root/dummy-debs" "$@.tmp/root/devrepo"
	cp $(CHROOT_DUMMY_PACKAGES_FILES) "$@.tmp/root/dummy-debs/"
	# Stub things which won't work in a chroot
	echo '#!/bin/sh' >"$@.tmp/root/helper/mknod"
	echo '#!/bin/sh' >"$@.tmp/root/helper/mount"
	printf 'APT::Get::AllowUnauthenticated "true";\nAcquire::AllowInsecureRepositories "true";' >"$@.tmp/etc/apt/apt.conf.d/80localnocheck"
	# Stub man stuff, because it may use seccomp, would hand qemu-user-static :(
	touch "$@.tmp/dev/null"
	chmod 666 "$@.tmp/dev/null"
	chmod +x "$@.tmp/root/helper/mknod" "$@.tmp/root/helper/mount"
	$(SETUPBUILDENV) uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/$@.tmp" /debootstrap/debootstrap --second-stage
	printf "deb %s %s main\ndeb-src %s %s main\n" "$(REPO)" "$(RELEASE)" "$(REPO)" "$(RELEASE)" >"$@.tmp/etc/apt/sources.list"
	$(SETUPBUILDENV) uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/$@.tmp" apt-get update
	$(SETUPBUILDENV) uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/$@.tmp" sh -c "dpkg -i /root/dummy-debs/*.deb"
	$(SETUPBUILDENV) uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/$@.tmp" apt-get -y install --no-install-recommends build-essential dh-make debhelper devscripts fakeroot
	printf "deb file:///root/devrepo/ ./\n" "$(REPO)" "$(RELEASE)" "$(REPO)" "$(RELEASE)" >>"$@.tmp/etc/apt/sources.list"
	mv "$@.tmp" "$@"

build-env/$(RELEASE)/root/%/src/.source: repo/%/.repo build-env/$(RELEASE)
	mkdir -p "$(dir $(dir $(dir $@)))"
	rm -rf "$(dir $(dir $@))"
	cp -r "$(dir $<)" "$(dir $@)"
	touch "$@"

bin/$(RELEASE)/deb-%/.build: build-env/$(RELEASE)/root/%/src/.source
	find "$(<:%/src/.source=%)/" -maxdepth 1 -type f -delete
	$(SETUPBUILDENV) uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/build-env/$(RELEASE)" sh -c "\
	  set -ex; \
	  cd /root/devrepo/; \
	  rm -f Packages Packages.gz Packages.xz; \
	  dpkg-scanpackages -m . > Packages; \
	  gzip -k Packages; \
	  xz -k Packages; \
	  cd /root/$(notdir $(<:build-env/$(RELEASE)/root/%/src/.source=%))/src/; \
	  apt-get update; \
	  apt-get -y build-dep .; \
	  debuild -b -us -uc; \
	  cp ../*.deb /root/devrepo/; \
	"
	mkdir -p "$(dir $@)"
	find "$(<:%/src/.source=%)" -maxdepth 1 -iname '*.deb' -not -iname '*dbgsym*' -exec cp {} "$(dir $@)/" \; ; \
	touch "$@"

clean-repo: clean-repo@flash-kernel
reset-repo: reset-repo@flash-kernel

clean-buildenv:
	$(SETUPBUILDENV) uexec rm -rf "$(CURDIR)/build-env/$(RELEASE)"

clean-build:
	rm -rf bin/$(RELEASE)
