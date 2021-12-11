# DPA image builder

I've written my own image builder to create my own, custom, devuan based images.
Originally, I did this to run devuan & some other stuff of mine on the librem5,
but it can now also make images for other devices (the pinephone-pro), and
can also make images for other debian & debootstrap based distributions.

While this image builder can bootstrap images based on the repositories of various linux distros,
and can thus create images based on devuan, debian, ubuntu, etc. Please note that this
aren't official images and that they do contain some files and packages not (yet?) available upstream.

I'm building these images every day at 0 UTC on my build server: https://repo.dpa.li/apt/librem5/images/ (Please note that the base images don't contain a desktop environment)

This project is still a work in progress, it's not ready for regular usage yet.

# Required packages & programs

You need the following packages for this to work:
 * `make`
 * `gcc`
 * `gcc-aarch64-linux-gnu`
 * `libc6-dev-arm64-cross`
 * `gcc-arm-none-eabi`
 * `libnewlib-arm-none-eabi`
 * `libstdc++-arm-none-eabi-newlib`
 * `libext2fs-dev` (a newer, renamed version of e2fslibs-dev, if you use devuan ascii, it's in ascii-backports)
 * `util-linux`
 * `libtar-dev`
 * `bison`
 * `flex`
 * `fuse`
 * `device-tree-compiler`
 * `comerr-dev`
 * `jq`
 * `equivs`
 * `qemu-user-static` (for /usr/bin/qemu-aarch64-static, needed on non-aarch64 hosts only)
 * `uidmap`
 * `binfmt-support` (optional)

## Other requirements & things to check first

These build scripts take advantage of the linux kernels unprivileged user namespace
feature, subuids and subgids to to run commands in the chroot environment it bootstraps
as if they where run as root or some other user, while they actually run as the current
user or one of it's subuids. For this to work, please first check the following.

Verify that unprivileged user namespaces are enabled: `sysctl kernel.unprivileged_userns_clone`.
If they aren't, they can either be enable temporarely: `sysctl kernel.unprivileged_userns_clone=1`,
or permanently by adding the line `kernel.unprivileged_userns_clone = 1` to
`/etc/sysctl.conf` and reloading it using `sysctl -p`.

The user the build script runs as should have at least 65536 subuids and subgids
(because 65536:65536 is always nobody:nogroup). The files `/etc/subuid` and
`/etc/subgid` contain all subuids and subgids and are an easy way to check if a
user has any. To add new subuids and subgids, you can use the `usermod` program.
The subuids shouldn't overlap with any existing uids or subuids, because a user
can switch to it's subuids. Usually, just using the uids after the biggest/last
used subuid is a good idea.

## Usage

Everithing in this repo is designed to work without root. I haven't tested if it even works when run as root.

Creating an image in bin/$(DISTRO)-$(RELEASE)-$(BOARD)-$(VARIANT).img
```
make
```

| Variable | Default | Description |
| -------- | ------- | ----------- |
| BOARD |  | For which board the image is to be built. For example "librem5-devkit", "librem5-phone" or "pinephone-pro". |
| IMGSIZE | 3GiB | The size of the image. Can be specified in GB, GiB, MB, MiB, etc. |
| DISTRO | devuan | The distribution the image is based on |
| RELEASE | chimaera | The release of the disribution to debootstrap |
| VARIANT | base | A variation of the image to build, used to create image versions with some additional packages, repos, etc. |
| REPO | http://pkgmaster.devuan.org/merged/ | The repository to use for debootstraping |
| CHROOT_REPO | $REPO | The repository to use in the /etc/apt/sources.list |
| IMAGE_NAME | $(DISTRO)-$(RELEASE)-$(BOARD)-$(VARIANT).img | The name of the image |
| BUILD_PACKAGES | no | Wheter or not to build packages using chroot-build-helper at all |
| DONT_BUILD_IF_IN_REPO | yes | If the package to be built is already in the repo, don't rebuild it |
| USE_IMAGE_BUILDER_REPO | yes | Wheter or not to use and add a sources.list for $IMAGE_BUILDER_REPO. If you don't want to use another repo and instead build all package yourself, set this to "no" and also set $BUILD_PACKAGES to "yes". |
| IMAGE_BUILDER_REPO | `deb https://repo.dpa.li/apt/librem5/ $(DISTRO)-$(RELEASE) librem5` | If $USE_IMAGE_BUILDER_REPO is set to yes, this repos is used & added. |
| IMAGE_BUILDER_REPO_KEY | https://repo.dpa.li/apt/librem5/repo-public-key.gpg | If $USE_IMAGE_BUILDER_REPO is set to "yes", this repo key is added. |

You can use the config-set@% and the config-unset@% targets to change these variables or the urls or branches of any of the repos. See the next section on how to use that feature.

You can also specify them in the make command directly instead, but if you do it that way, you need to take care of the following yourself:

 * To change the IMGSIZE, you need to delete the image in bin/.
 * To change REPO and CHROOT_REPO, remove the build/filesystem directory, or the rootfs and bootfs tar archives in it.

There are also make targets for that.

Packages can be built even if BUILD_PACKAGES is set to "no". For this, just enter
the `chroot-build-helper` subdirectory. In there, you can use `make` as normal,
including the `repo`, `reset*` and `clean*` make targets. You can also build an individual
package that way, using the `make build@%` make target (just replace `%` with the repo name).

## Platform specific things

 * [Librem 5](platform/librem5/README.md)
 * [Pinephone Pro](platform/pinephone-pro/README.md)

## Other useful make targets

| Name | Purpose |
| ---- | ------- |
| all  | Build the image |
| config-list | List all config variables, this includes the repo urls and branches |
| [CONF=path/to/config] config-set@variable-name TO=new-value | Set variable-name to new-value in file conf/$CONF, which defaults to userdefined. This will also clean up or reset images and repos as needed. |
| [CONF=path/to/config] config-unset@variable-name | Remove variable from file conf/$CONF. This will also clean up or reset images and repos as needed. |
| bootloader | builds the uboot bootloader at uboot/bin/uboot_firmware_and_dtb.bin |
| enter-buildenv | Setup environment & PATH most scripts of this repo use & execute $SHELL (unfortunately, make sets thet to sh...) |
| linux | builds the kernel packages |
| clean-fs | Removes the tar archives which contain the bootstrapped rootfs and bootfs of the current release |
| emulate | Works with BOARD=imx8 only. Uses the image and kernel last built and tries to start it using qemu-system-aarch64. This works a lot different than how the devkit or phone would do it, but it is useful to check if the bootstrapping and init scripts work. |
| clean-fs-all | Removes the whole build/filesystem folder. This is enough for most purposes. |
| clean-image | Removes the image for the current release. |
| clean-image-all | Removes all images in the bin/ folder |
| repo | Clones all repositories into repo/* |
| repo@reponame | Clones the specified repository to repo/reponame |
| clean-build	| remove all build files. (the files in build/, bin/ etc.) |
| clean-repo | Completely removes all repositories |
| clean-repo@reponame | Completly removes repo/reponame |
| reset-repo | Remove all files in the repos except .git, cleanly check them out again from the local repo in .git, and update them if possible |
| reset-repo@reponame | same as the above, but for a speciffic repo |
| clean-all | short for clean-repo and clean-build, removes pretty much everithing. |
| reset | Short for reset-repo and clean-build, mostly the same as clean-all, but doesn't require downloading all repos again |
| chroot@path/to/env/ | Chroot to a directory. Useful to look into a build environment in chroot-build-helper/build-env/*/ and similar stuff. |

The urls and reponame of all used repositories as well as the defaults of most variables can be found in the config/ directory, with the exception of the imx firmware from nxp, which is still in src/repositories.mk.


## Modifying the image

All config settings, lists of packages to be installed, the packages to be built,
and additional files to be included in the image can be found in the `config/`
directory. The build script will combine the contents of the following subdirectories:
 * `default`
 * `default/v-$(VARIANT)`
 * `$(DISTRO)`
 * `$(DISTRO)/v-$(VARIANT)`
 * `$(DISTRO)/r-$(RELEASE)`
 * `$(DISTRO)/r-$(RELEASE)/v-$(VARIANT)`
 * `default/b-$(BOARD)`
 * `default/v-$(VARIANT)/b-$(BOARD)`
 * `$(DISTRO)/b-$(BOARD)`
 * `$(DISTRO)/v-$(VARIANT)/b-$(BOARD)`
 * `$(DISTRO)/r-$(RELEASE)/b-$(BOARD)`
 * `$(DISTRO)/r-$(RELEASE)/v-$(VARIANT)/b-$(BOARD)`

The list of directories to be searched is defined by the `CONFIG_PATH` variable,
which is set in the config file `config/default/conf`.

These subdirectories contain the following files:
 * `config`: Config settings
 * `install_debootstrap`: Packages to be installed by debootstrap.
 * `install_early`: Packages to be installed using apt after the bootstrapping.
 * `install_target`: Packages to be installed after the first boot.
 * `download`: Packages which are only downloaded (including the dependencies), but not installed.
 * `build`: Packages which have to be built from source. This must be a repo specified in the config which can be built using `debootstrap -us -uc -b`.
 * `defer_installation_of_problemetic_package`: Some packages may not be installable in a crossdev chroot. Packages in this file are temporarely replaced with a dummy package.

All config and package lists in the search path are combined. Config settings
in config files later in the path override earlier ones. The special config file
`config/user_config_override`, which is the default for the `config-set@%' and
`config-unset@%` makefile targets, can override the settings from all other config
files and will be ignored in the git repo. It is useful for changing local
settings & preferences, such as the repos to use for bootstrapping, the image
files size, or using a different branch or remote for a repo, or generally
just to thest things without having to worry about these settings being overritten
by later git pulls.

The directories in the `$CONFIG_PATH` can also contain a `rootfs` folder. This
folder contains additional files to be added to the image. If the same file
exists in multiple rootfs folders, the last one in the config path is chowsen.
These files can also have an extension with a special meaning:
 * `.in`: Uses envsubst to replace variables in the file. Use $$ to escape $.
 * `.rm`: If a file with that name & path exists after bootstrapping, remove it.
 * `.ignore`: If there was a file with the same name earlier in the config path, ignore it.

The recommended way of creating an image with your own additional packages & files
in it is to create a new image variant. Use `make config-set@VARIANT TO=your-new-variant`
to change the default variant. After that, you can check in which directories
the build script will now search the configs: `make config-list | grep '^CONFIG_PATH'`.
You can then add & make changes to the configs related to your new image variant.

Most of the scripts in this repo expect to be run with the environment provided
by the makefile. You can get a shell `make enter-buildenv` with this environment.
All scripts and binaries are then automatically in the PATH. You can also check
your config settings this way. For example, to check which packages it picked up,
you can use the command `env | grep '^PACKAGES'`. To see the config search path
with one path per line, you can use `printf '%s\n' $CONFIG_PATH`, and so on.
It's recommended to exit this shell before building the images though.

## Automatically creating & adding built packages to a repo

Just install reprepro and set the following variables:

| Variable | Purpose |
| -------- | ------- |
| ADD_TO_EXTERNAL_REPO | Set this to "yes" to automatically add packages to a repo |
| REPO_DIR | The directory in which the files for the repo shall be stored. The actual repo will be in a subdirectory called "repo/". Use an absolute path here. |
| NEW_PKG_ORIGIN | Set the origin for the repo |
| NEW_PKG_COMPONENT | Set the component of the repo |
| NEW_PKG_KEY | Set the GPG key to use for signing |

You may also want to change: BUILD_PACKAGES, USE_IMAGE_BUILDER_REPO,
IMAGE_BUILDER_REPO and IMAGE_BUILDER_REPO_KEY. See section [Usage] for details.

You can build the packages even if BUILD_PACKAGES is set to no

## Other important stuff

The license in this repository only applies to the files in this repository.
Other repositories loaded by these scripts often use different licenses,
and the parts of the files generated using these sources in turn have the license restrictions
that come with the corresponding sources applied to them.

Things unpacked after the debootstrapping currently don't have acls applied to them.
I don't know if any package unpacked at that stage would have them otherwise, but it's something I should
fix eventually and which should be kept in mind when adding packages to that phase of debootstrapping.
