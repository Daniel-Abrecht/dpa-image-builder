include ../src/make-helper-functions.mk

CURDIR=$(realpath .)

TARGETS += deb-flash-kernel
TARGETS += deb-consolation
TARGETS += deb-libttymultiplex
TARGETS += deb-libconsolekeyboard
TARGETS += deb-console-keyboard-basic
TARGETS += deb-console-keyboard-multiplexer

TARGETS += $(CROSSBUILD_SOURCE_PACKAGES)

# Packages using seccomp will hang qemu-user, so let's replace them
CHROOT_DUMMY_PACKAGES += man-db

CHROOT_DUMMY_PACKAGES_FILES = $(addprefix dummy-packages/,$(addsuffix -dummy_99_all.deb,$(CHROOT_DUMMY_PACKAGES)))

all: $(addprefix build@,$(TARGETS))

deb-console-keyboard-basic: deb-libconsolekeyboard
deb-console-keyboard-multiplexer: deb-libconsolekeyboard deb-libttymultiplex deb-console-keyboard-basic

pkg-repo@deb-%: repo@%
	@true

repo: $(addprefix pkg-repo@,$(TARGETS))

build@%: bin/$(DISTRO)/$(RELEASE)/%/.build
	@true

dummy-packages/%-dummy_99_all.deb: dummy-packages/%
	cd "$(dir $<)"; equivs-build "$(notdir $<)"

build-env/$(DISTRO)/$(RELEASE): build-env/.dir $(CHROOT_DUMMY_PACKAGES_FILES)
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
	CHROOT_REPO="$$REPO" ../script/getrfsfile.sh "rootfs_custom_files/etc/apt/sources.list" >"$@.tmp/etc/apt/sources.list"
	$(SETUPBUILDENV) uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/$@.tmp" apt-get update
	$(SETUPBUILDENV) uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/$@.tmp" sh -c "dpkg -i /root/dummy-debs/*.deb"
	$(SETUPBUILDENV) uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/$@.tmp" apt-get -y install --no-install-recommends build-essential dh-make debhelper devscripts fakeroot
	printf "\ndeb file:///root/devrepo/ ./\n" >>"$@.tmp/etc/apt/sources.list"
	mv "$@.tmp" "$@"

build-env/$(DISTRO)/$(RELEASE)/root/%/src/.source: repo/%/.repo build-env/$(DISTRO)/$(RELEASE)
	mkdir -p "$(dir $(dir $(dir $@)))"
	rm -rf "$(dir $(dir $@))"
	cp -r "$(dir $<)" "$(dir $@)"
	touch "$@"

bin/$(DISTRO)/$(RELEASE)/deb-%/.build: build-env/$(DISTRO)/$(RELEASE)/root/%/src/.source
	find "$(<:%/src/.source=%)/" -maxdepth 1 -type f -delete
	$(SETUPBUILDENV) uexec --allow-setgroups chroot_qemu_static.sh "$(CURDIR)/build-env/$(DISTRO)/$(RELEASE)" sh -c "\
	  set -ex; \
	  cd /root/devrepo/; \
	  rm -f Packages Packages.gz Packages.xz; \
	  dpkg-scanpackages -m . > Packages; \
	  gzip -k Packages; \
	  xz -k Packages; \
	  dpkg --remove \$$(grep '^Package: ' Packages | grep -o '[^ ]*$$') || true; \
	  cd /root/$(notdir $(<:build-env/$(DISTRO)/$(RELEASE)/root/%/src/.source=%))/src/; \
	  apt-get update; \
	  apt-get -y build-dep .; \
	  debuild -b -us -uc; \
	  cp ../*.deb /root/devrepo/; \
	"
	mkdir -p "$(dir $@)"
	find "$(<:%/src/.source=%)" -maxdepth 1 -iname '*.deb' -not -iname '*dbgsym*' -exec cp {} "$(dir $@)/" \; ; \
	touch "$@"

pkg-clean-repo@deb-%: clean-repo@%
	@true

clean-repo: $(addprefix pkg-clean-repo@,$(TARGETS))

pkg-reset-repo@deb-%: reset-repo@%
	@true

reset-repo: $(addprefix pkg-reset-repo@,$(TARGETS))

clean-buildenv:
	$(SETUPBUILDENV) uexec rm -rf "$(CURDIR)/build-env/$(DISTRO)/$(RELEASE)"
	rmdir "$(CURDIR)/build-env/$(DISTRO)/" || true
	rmdir "$(CURDIR)/build-env/" || true

clean-build:
	rm -rf bin/$(DISTRO)/$(RELEASE)
	rmdir bin/$(DISTRO)/ || true
	rmdir bin || true
