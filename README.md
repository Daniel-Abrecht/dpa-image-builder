# librem5 devkit image build scripts

While waiting for the devkit to arrive, I've written a few buildscripts to
create a devuan image based on the ones from purism: https://source.puri.sm/Librem5/image-builder

I do a few things differently though, and I didn't reuse any code from their image-builder repo,
with the exception of the uboot boot script at rootfs_custom_files/boot/boot.txt.

I did this to get a devuan image for the devkit, and to gain a better understanding
of the boot process and the components used. I also wanted to make sure that I
can compile everything myself. Note that there are still a few proprietary firmware
blobs from nxp for the hdmi/display I'd like to get rid of.

I have never actually tried to run the build scripts from purism, but it they should
mostly work for devuan too, aside from a few systemd specific things, mostly in
root.sh, which would probably have to be changed.

Please note that since I don't have the devkit yet, I have no idea if the image
actually works.

## Usage

Everithing in this repo is designed to work without root. I haven't testet if it even works when run as root.

Creating an image in bin/devuan-$(RELEASE)-librem5-$(BOARD)-base.img
```
make
```

You may have to install a few packages such as make, gcc, gcc-aarch64-linux-gnu, gcc-arm-none-eabi, libext2fs-dev, libtar-dev, and probably a few more for this to work.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| BOARD | devkit | Board specific config. Specifies which configs/board-$(BOARD).mk config file to use. |
| IMGSIZE | 32GB | The size of the image. Can be specified in GB, GiB, MB, MiB, etc. |
| RELEASE | ascii | The release to debootstrap |
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
| CONF=userdefined config-set@variable-name TO=new-value | Set variable-name to new-value in file conf/$CONF.mk, which defaults to userdefined. This will also clean up or reset images and repos as needed. |
| CONF=userdefined config-unset@variable-name | Remove variable from file conf/$CONF.mk. This will also clean up or reset images and repos as needed. |
| bootloader | builds the uboot bootloader at uboot/bin/uboot_firmware_and_dtb.bin |
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

The urls and reponame of all used repositories as well as the defaults of most variables can be found in the config/ directory, with the exception of the imx firmware from nxp, which is still in src/repositories.mk.


## Modifying the image

To add any files to the image, just add them to the rootfs_custom_files folder.
To install any additional packages, add them to the include_packages file.
These package will be installed after the first boot.
To install any packages even earlier with the debootstrap, add them to the include_packages_early file.
To do things after the first boot, add them to the rootfs_custom_files/etc/rc.local file.

## Other important stuff

There are currently 5 Proprietary binary blobs from nxp contained in the final uboot binary with non-free licenses, probably all for similar things, namely:
 * lpddr4_pmu_train_1d_dmem.bin
 * lpddr4_pmu_train_1d_imem.bin
 * lpddr4_pmu_train_2d_dmem.bin
 * lpddr4_pmu_train_2d_imem.bin
 * signed_hdmi_imx8m.bin
 
I have yet to check if these firmware blobs are all really necessary, or if they can be removed somehow.
I haven't asked purism about them yet, so I don't know if they intend to remove them at some point or not.
Everything else uses common open source licenses though.

The license in this repository only applies to the files in this repository.
Other repositories loaded by these scripts often use different licenses,
and the parts of the files generated using these sources in turn have the license restrictions
that come with the corresponding sources applied to them.

Things unpacked after the first stage of debootstrapping currently don't have acls applied to them.
I don't know if any package unpacked at that stage would have them otherwise, but it's something I should
fix eventually and which should be kept in mind when adding packages to that phase of debootstrapping.
