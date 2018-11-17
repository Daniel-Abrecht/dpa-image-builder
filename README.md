# librem5 devkit image build scripts

While waiting for the devkit to arrive, I've written a few buildscripts to
create a devuan image based on the ones from purism: https://source.puri.sm/Librem5/image-builder

I do a few things differently though, and I didn't reuse any code from their image-builder repo.

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

Creating an image in bin/devuan-$RELEASE-imx8-base.img
```
make
# Same as:
make IMGSIZE=32GB RELEASE=ascii REPO=http://pkgmaster.devuan.org/merged/ CHROOT_REPO=http://pkgmaster.devuan.org/merged/
```

You may have to install a few packages such as make, gcc, gcc-aarch64-linux-gnu, gcc-arm-none-eabi, and probably a few more for this to work.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| IMGSIZE | 32GB | The size of the image. Can be specified in GB, GiB, MB, MiB, etc. |
| RELEASE | ascii | The release to debootstrap |
| REPO | http://pkgmaster.devuan.org/merged/ | The repository to use for debootstraping |
| CHROOT_REPO | $REPO | The repository to use in the /etc/apt/sources.list |

You can change RELEASE and it will do everithing necessary to create the image for the other release.
To change the IMGSIZE, you need to delete the image in bin/.
To change REPO and CHROOT, remove the build/filesystem directory.

When in doubt, and you want to bootstrap the image again, you can also just delete bin/ and build/.

You may not want to run ```make clean```, because that cleans up everything, including all repos and so on,
and it takes forever to download and compile that all again.

## Modifying the image

To add any files to the image, just add them to the rootfs_custom_files folder.
To install any additional packages, add them to the include_packages file.
These package will be installed after the first boot.
To install any packages even earlier with the debootstrap, add them to the include_packages_early file.
To do things after the first boot, add them to the rootfs_custom_files/etc/rc.local file.

## Other important stuff

The build scripts from purism blacklist the touchscreen driver rmi-i2c in order to modprobe it after the hdmi driver has been initialised.
I don't do that yet, and want to see first if this is really necessary.

There are currently 5 Proprietary binary blobs from nxp contained in the final uboot binary with non-free licenses, probably all for similar things, namely:
 * lpddr4_pmu_train_1d_dmem.bin
 * lpddr4_pmu_train_1d_imem.bin
 * lpddr4_pmu_train_2d_dmem.bin
 * lpddr4_pmu_train_2d_imem.bin
 * signed_hdmi_imx8m.bin
 
I have yet to check if these firmware blobs are all really necessary, or if they can be removed somehow.
Please note also, purism doesn't have an official image yet, and they may or may not remove these eventually if they find a way,
so if they will include them in the final image isn't known yet, and I haven't asked them about it either.
Everything else uses common open source licenses though.

The license in this repository only applies to the files in this repository.
Other repositories loaded by these scripts often use different licenses,
and the parts of the files generated using these sources in turn have the license restrictions
that come with the corresponding sources applied to them.

Things unpacked after the first stage of debootstrapping don't have acls applied to them.
I don't know if any package unpacked at that stage would have them otherwise, but it's something I should
fix eventually and which should be kept in mind when adding packages to that phase of debootstrapping.
