#Concerto Player
Builds a live image that runs as a kiosk that is integrated with bandshell for displaying concerto content. For production purposes, it should be built on a **64-bit Debian** box (Ubuntu can introduce some subtle differences) and the passwords in password.sh should be changed.

## Building the Image
On a basic debian install do the following.  If you run in the root terminal then you wont need the `sudo`'s.
* `sudo apt-get install debootstrap squashfs-tools syslinux syslinux-common syslinux-utils apt-cacher-ng git-core`
* `git clone https://github.com/concerto/concerto-player.git`
* `cd concerto-player`
* ...maybe edit chroot_tasks.sh
* ...maybe edit passwords.sh
* `sudo ./make_chroot.sh 2>&1 | tee make_chroot.log`
* `sudo ./make_bootable_image.sh 2>&1 | tee make_bootable_image.log`

## Testing the Image
In qemu:
* `qemu-system-x86_64 -m 1024 -snapshot -hda concerto.img`

##Pre-built image
A pre-built raw image is available at:
http://dl.concerto-signage.org/concerto_player-0.9.0.img.zip

A pre-built VM image for testing purposes is available at:
http://dl.concerto-signage.org/concerto_player-0.9.0.vmdk

## Placing on Flash Drive
Make sure you substitute *your* flash drive device for the output file _of_ parameter.  `lsusb` might be helpful in finding out what yours is.
* `sudo dd if=concerto.img of=/dev/sdX`
 
## Background
apt-cacher-ng is recommended for development purposes (to reduce load on the Debian mirrors), and the default mirror URL is set up with this in mind. If you don't want to use apt-cacher-ng (e.g. you're only building this once), you may edit make_chroot.sh and change the MIRROR_URL to your preferred Debian mirror.

chroot_tasks.sh is run once a basic system is established, in the context of the new system, and sets up the stuff needed for Concerto.

### Technical Details...

The way it works is that you run make_chroot.sh as root. This uses debootstrap to set up a base system, then runs chroot_tasks.sh inside that system to set up whatever needs to be set up. The policy-rc.d stuff is needed to prevent the new system's daemons being started up in the build system.

Taking a look at chroot_tasks.sh, a few things happen. The X server, chromium, unclutter, and a few other useful things are installed. A kernel and live-boot also are installed, this is so we can use the Debian kernels and not have to worry about compiling our own. live-boot plugs into the Debian initrd framework and sets up the squashfs/unionfs stuff. 

chroot_tasks.sh next sets up a user account 'concerto' with 'xinit' as its shell. and creates an .xinitrc file. First, it launches a window manager (blackbox), because without one chromium doesn't really like to go fullscreen properly. Next. it starts unclutter which is responsible for hiding the mouse pointer. Both these tasks are started in the background. Finally, chromium is started in fullscreen kiosk mode in the foreground, so that when it exits, the xinitrc script will also terminate and cause the X server to shut down.

Next, the /etc/inittab is edited so that the concerto user is automatically logged in. The 'concerto' user will be logged in again if logged out (e.g. chromium dies or is terminated for some reason), hopefully making sure that the browser stays up more or less continuously.

Last but not least, passwords are set up for the root and concerto users.

Once make_chroot.sh is finished, the live filesystem exists in chroot/. Running make_bootable_image.sh (which also must run as root) will create a 1GB hard disk image formatted as FAT16, install the syslinux bootloader, copy the kernel and initrd from the live system to where they need to go, and generate a syslinux.cfg file. It also makes a squashfs image of the chroot directory and puts that in the filesystem under /live, where live-boot's initrd will find it. When all is said and done you can test it with qemu-system-x86_64 -m 1024 -snapshot -hda concerto.img.  Or you can convert it to a vmdk for vmware with `qemu-img convert concerto.img -O vmdk concerto-player.vmdk`




[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/concerto/concerto-player/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

