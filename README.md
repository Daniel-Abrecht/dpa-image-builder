# librem5 devkit image build scripts

I've written a few buildscripts to create my own, devuan image based on the ones from purism: https://source.puri.sm/Librem5/image-builder

I do a few things differently though, and I didn't reuse any code from their image-builder repo,
with the exception of the uboot boot script at rootfs_custom_files/boot/boot.txt.

I did this to get a devuan image for the devkit, and to gain a better understanding
of the boot process and the components used. I also wanted to make sure that I
can compile everything myself and that I will have a booting image once the phone arrives.

I have never actually tried to run the build scripts from purism, but they should
mostly work for devuan too, aside from a few systemd specific things, mostly in
root.sh, which would probably have to be changed.

The image does boot, but only from emmc when flashed using uuu, and an uart connection
is currently needed to see any of the output, since the screen doesn't work yet.
There is still a lot to do.

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
 * `libtar-dev`
 * `bison`
 * `flex`
 * `device-tree-compiler`
 * `comerr-dev`
 * `jq`
 * `equivs`
 * `debootstrap`
 * `qemu-user-static` (for /usr/bin/qemu-aarch64-static, needed on non-aarch64 hosts only)
 * `uidmap`
 * `binfmt-support` (optional)

Setting up binfmt-misc on non-aarch64 hosts is not necessary, but recommended.
It may speed up the build process and make the bootstrapping more reliable.
It should happen automatically if you install qemu-user-static.
Don't install qemu-user-binfmt, it's qemu-user binaries arent statically built and won't work for this.

For flashing the image, you'll also need uuu. You can get uuu from https://source.puri.sm/Librem5/mfgtools
Just make sure uuu is in your path when flashing the image. I've just copied the
built binaries to /usr/local: `cp uuu/uuu /usr/local/bin/; cp libuuu/libuuu* /usr/local/lib/;`

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

Creating an image in bin/devuan-$(RELEASE)-librem5-$(BOARD)-base.img
```
make
```

| Variable | Default | Description |
| -------- | ------- | ----------- |
| BOARD | devkit | Board specific config. Specifies which configs/board-$(BOARD).mk config file to use. |
| IMGSIZE | 3GiB | The size of the image. Can be specified in GB, GiB, MB, MiB, etc. |
| DISTRO | devuan | The distribution |
| RELEASE | beowulf | The release of the disribution to debootstrap |
| VARIANT | base | A variation of the image to build, used to create image versions with some additional packages, repos, etc. |
| REPO | http://pkgmaster.devuan.org/merged/ | The repository to use for debootstraping |
| CHROOT_REPO | $REPO | The repository to use in the /etc/apt/sources.list |
| IMAGE_NAME | devuan-$(RELEASE)-librem5-$(BOARD)-base.img | The name of the image |

You can use the config-set@% and the config-unset@% targets to change these variables or the urls or branches of any of the repos. See the next section on how to use that feature.

You can also specify them in the make command directly instead, but if you do it that way, you need to take care of the following yourself:

 * To change the IMGSIZE, you need to delete the image in bin/.
 * To change REPO and CHROOT_REPO, remove the build/filesystem directory, or the rootfs and bootfs tar archives in it.

There are also make targets for that.

## Other useful make targets

| Name | Purpose |
| ---- | ------- |
| all  | Build the image |
| config-list | List all config variables, this includes the repo urls and branches |
| [CONF=path/to/config] config-set@variable-name TO=new-value | Set variable-name to new-value in file conf/$CONF, which defaults to userdefined. This will also clean up or reset images and repos as needed. |
| [CONF=path/to/config] config-unset@variable-name | Remove variable from file conf/$CONF. This will also clean up or reset images and repos as needed. |
| uuu-flash | flash the image to emmc0 using uuu. You can specify a different image using IMAGE_NAME. If this image doesn't have an uboot usable for flashing, use IMAGE_UBOOT_UNFLASHABLE=1 to use the uboot from uboot/bin/uboot_firmware_and_dtb.bin instead for that step. |
| uuu-uboot-flash | flash uboot (doesn't include m4) |
| uuu-test-uboot | Just boot using uboot bootloader from uboot/bin/uboot_firmware_and_dtb.bin (doesn't quiet work as intended yet) |
| uuu-test-uboot@image | Just boot using uboot bootloader from bin/$(IMAGE_NAME). (doesn't quiet work as intended yet) |
| uuu-test-kernel | Just boot using kernel from .(kernel/bin/linux-image-*.deb. (doesn't quiet work as intended yet) |
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
you can use the command `env | grep '^PACKAGES'`. To enter the config search path
with one path per line, you can use `printf '%s\n' $CONFIG_PATH`, and so on.
It's recommended to exit this shell before building the images though.

## Other important stuff

There are currently 5 Proprietary binary blobs from nxp contained in the final uboot binary with non-free licenses:
 * `lpddr4_pmu_train_1d_dmem.bin`
 * `lpddr4_pmu_train_1d_imem.bin`
 * `lpddr4_pmu_train_2d_dmem.bin`
 * `lpddr4_pmu_train_2d_imem.bin`
 * `signed_hdmi_imx8m.bin`

One of the `lpddr4_*.bin` files is required for training the DDR PHY. The HDMI bin file is for DRM HDMI signals.
All of the `lpddr4_*.bin` firmware files are currently needed to build uboot and thus the image.

The license in this repository only applies to the files in this repository.
Other repositories loaded by these scripts often use different licenses,
and the parts of the files generated using these sources in turn have the license restrictions
that come with the corresponding sources applied to them.

Things unpacked after the debootstrapping currently don't have acls applied to them.
I don't know if any package unpacked at that stage would have them otherwise, but it's something I should
fix eventually and which should be kept in mind when adding packages to that phase of debootstrapping.
