include ../src/make-helper-functions.mk

TMPDEP := $(shell mktemp)
$(shell make -f "../src/make-helper-functions.mk" TMP_TARGET_FILE="$(TMPDEP)" DEP_PREFIX="bin/$(DISTRO)/$(RELEASE)/" DEP_SUFFIX="/.build" generate_make_build_dependencies_for_debs >/dev/null)
include $(TMPDEP)

bla:
	echo

# Only one thing at a time can chroot into the buildenv
.NOTPARALLEL:

CURDIR=$(realpath .)

# Packages using seccomp will hang qemu-user, so let's replace them
CHROOT_DUMMY_PACKAGES_FILES = $(addprefix dummy-packages/,$(addsuffix .deb,$(PACKAGES_BOOTSTRAP_WORKAROUND)))

all: $(addprefix build@,$(PACKAGES_TO_BUILD)) $(CHROOT_DUMMY_PACKAGES_FILES)
repo: $(addprefix repo@,$(PACKAGES_TO_BUILD))

build@%: bin/$(DISTRO)/$(RELEASE)/%/.build
	@true

dummy-packages/%.deb:
	mkdummydeb.sh "$@"

build-env/$(DISTRO)/$(RELEASE): build-env/.dir $(CHROOT_DUMMY_PACKAGES_FILES)
	mkdir -p "$@.tmp"
	uexec rm -rf "$(CURDIR)/$@.tmp"
	uexec --allow-setgroups debootstrap --foreign --arch=arm64 "$(RELEASE)" "$(CURDIR)/$@.tmp" "$(REPO)"
	mkdir -p "$@.tmp/root/helper" "$@.tmp/root/dummy-debs" "$@.tmp/root/devrepo"
	cp $(CHROOT_DUMMY_PACKAGES_FILES) "$@.tmp/root/dummy-debs/"
	# Stub things which won't work in a chroot
	echo '#!/bin/sh' >"$@.tmp/root/helper/mknod"
	chmod +x "$@.tmp/root/helper/mknod"
	echo '#!/bin/sh' >"$@.tmp/root/helper/mount"
	chmod +x "$@.tmp/root/helper/mount"
	printf 'APT::Get::AllowUnauthenticated "true";\nAcquire::AllowInsecureRepositories "true";' >"$@.tmp/etc/apt/apt.conf.d/80localnocheck"
	# Stub man stuff, because it may use seccomp, would hand qemu-user-static :(
	touch "$@.tmp/dev/null"
	chmod 666 "$@.tmp/dev/null"
	uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/$@.tmp" /debootstrap/debootstrap --second-stage
	CHROOT_REPO="$$REPO" getrfsfile.sh "rootfs_custom_files/etc/apt/sources.list" >"$@.tmp/etc/apt/sources.list"
	uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/$@.tmp" apt-get update
	uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/$@.tmp" sh -c "dpkg -i /root/dummy-debs/*.deb"
	uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/$@.tmp" apt-get -y install --no-install-recommends build-essential dh-make debhelper devscripts fakeroot
	printf "\ndeb file:///root/devrepo/ ./\n" >>"$@.tmp/etc/apt/sources.list"
	mv "$@.tmp" "$@"

build-env/$(DISTRO)/$(RELEASE)/root/%/src/.source: repo/%/.repo build-env/$(DISTRO)/$(RELEASE)
	mkdir -p "$(dir $(dir $(dir $@)))"
	rm -rf "$(dir $(dir $@))"
	cp -r "$(dir $<)" "$(dir $@)"
	touch "$@"

bin/$(DISTRO)/$(RELEASE)/%/.build: build-env/$(DISTRO)/$(RELEASE)/root/%/src/.source
	find "$(<:%/src/.source=%)/" -maxdepth 1 -type f -delete
	uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/build-env/$(DISTRO)/$(RELEASE)" sh -c "\
	  set -ex; \
	  cd /root/devrepo/; \
	  rm -f Packages Packages.gz Packages.xz; \
	  dpkg-scanpackages -m . > Packages; \
	  gzip -k Packages; \
	  xz -k Packages; \
	  for package in \$$(grep '^Package: ' Packages | grep -o '[^ ]*$$'); \
	    do apt-get purge "$$package"; \
	  done; \
	  apt-get autoremove --purge; \
	  cd /root/$(notdir $(<:build-env/$(DISTRO)/$(RELEASE)/root/%/src/.source=%))/src/; \
	  apt-get update; \
	  apt-get -y build-dep .; \
	  debuild -b -us -uc; \
	  cp ../*.deb /root/devrepo/; \
	"
	mkdir -p "$(dir $@)"
	find "$(<:%/src/.source=%)" -maxdepth 1 -iname '*.deb' -not -iname '*dbgsym*' -exec cp {} "$(dir $@)/" \; ; \
	touch "$@"

clean-repo: $(addprefix clean-repo@,$(PACKAGES_TO_BUILD))
reset-repo: $(addprefix reset-repo@,$(PACKAGES_TO_BUILD))

clean-buildenv:
	uexec rm -rf "$(CURDIR)/build-env/$(DISTRO)/$(RELEASE)"
	rmdir "$(CURDIR)/build-env/$(DISTRO)/" || true
	rmdir "$(CURDIR)/build-env/" || true

clean-build:
	rm -rf bin/$(DISTRO)/$(RELEASE)
	rmdir bin/$(DISTRO)/ || true
	rmdir bin || true
