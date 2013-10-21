#!/bin/sh -e

# set up variables so that config prompts are not displayed
export LC_ALL="C"
export LANGUAGE="C"
export LANG="C"
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

case `dpkg --print-architecture` in
i386)
	KERNEL=linux-image-686-pae
	;;
amd64)
	KERNEL=linux-image-amd64
	;;
*)
	echo "we don't support this architecture"
	exit 1
	;;
esac

# install packages we need (build-essential is temporary)
apt-get -y install xserver-xorg xserver-xorg-video-all \
	chromium unclutter ifplugd xinit blackbox \
	ruby1.9.1-full build-essential \
	vim screen git-core openssh-server \
	firmware-linux-nonfree

# and rubygems we need
#gem install bandshell
cat > /tmp/install_bandshell.sh <<EOF
#!/bin/sh -e
cd /tmp
git clone git://github.com/concerto/bandshell.git
cd bandshell
gem build bandshell.gemspec
gem install *.gem
cd /
rm -rf /tmp/bandshell
EOF
chmod +x /tmp/install_bandshell.sh
/tmp/install_bandshell.sh

# once rubygems have been installed, build-essential isn't needed
apt-get -y purge build-essential
apt-get -y autoremove

# install live-boot so we get an initrd built for us
apt-get -y install live-boot live-boot-initramfs-tools ${KERNEL}

# clean up apt caches
apt-get -y clean

# set up hostname
echo concerto-player > /etc/hostname

# create a user account that, when logged in, 
# will start the X server and the player
useradd -m -s `which xinit` concerto

# create a .xinitrc that will start fullscreen chromium
cat > /home/concerto/.xinitrc << "EOF"
#!/bin/sh
URL=`cat /proc/cmdline | perl -ne 'print "$1\n" if /concerto.url=(\S+)/'`
if [ -z $URL ]; then
	URL=http://localhost:4567/screen
fi

# start window manager
blackbox &

# hide the mouse pointer
unclutter &

# run the browser (if it crashes or dies, the X session should end)
chromium --no-first-run --kiosk $URL
EOF

# modify inittab so we auto-login at boot as concerto
sed -i -e 's/getty 38400 tty2/getty -a concerto tty2/' /etc/inittab

# create rc.local file to start bandshell
cat > /etc/rc.local << EOF
#!/bin/sh -e
/usr/local/bin/bandshelld start
EOF

# create init script to preload bandshell network config
cat > /etc/init.d/concerto-live << "EOF"
#!/bin/sh
### BEGIN INIT INFO
# Provides:		concerto-live
# Required-Start:	$local_fs
# Required-Stop:	$local_fs
# X-Start-Before:	$network
# Default-Start:	S
# Default-Stop:		0 6
# Short-Description:	Live system configuration for Concerto
# Description:		Live system configuration for Concerto
### END INIT INFO

. /lib/lsb/init-functions

MOUNTPOINT=/lib/live/mount/medium
MEDIUM_PATH_DIR=/etc/concerto
MEDIUM_PATH_FILE=medium_path

case "$1" in
start)
	log_action_begin_msg "Configuring Concerto Player"
	# try to remount boot medium as read-write
	# we don't care if this fails, the bandshell code will figure it out
	mount -o remount,rw,sync $MOUNTPOINT || true

	# create file indicating where mountpoint is
	mkdir -p $MEDIUM_PATH_DIR
	echo -n $MOUNTPOINT > $MEDIUM_PATH_DIR/$MEDIUM_PATH_FILE

	# generate /etc/network/interfaces from our configs
	/usr/local/bin/concerto_netsetup
	log_action_end_msg $?
	;;
stop)
	;;
esac
EOF

chmod +x /etc/init.d/concerto-live
update-rc.d concerto-live defaults

# create init script to load ssh keys from boot medium
cat > /etc/init.d/ssh-keys << "EOF"
#!/bin/sh -e
### BEGIN INIT INFO
# Provides:		ssh-keys
# Required-Start:	$local_fs
# Required-Stop:	$local_fs
# X-Start-Before:	sshd
# Default-Start:	2 3 4 5
# Default-Stop:		
# Short-Description:	Load SSH keys from boot medium
### END INIT INFO

. /lib/lsb/init-functions

MOUNTPOINT=`cat /etc/concerto/medium_path`

case "$1" in
start)
	log_action_begin_msg "Configuring SSH host keys"

	# make sure any keys that were part of the live image are gone
	rm -f /etc/ssh/ssh_host_*

	if [ -f $MOUNTPOINT/ssh_keys.tar ]; then
		# if keys are found stored on the boot medium, load them
		# IMPORTANT NOTE: unless you are really sure you know what
		# you are doing, you should NOT put an ssh_keys.tar file on
		# the boot medium. Instead, let this script generate it on
		# first boot. This way, a unique set of keys will be generated
		# for each box.
		tar -xvf $MOUNTPOINT/ssh_keys.tar -C /etc/ssh
	else
		# generate the necessary keys
		ssh-keygen -A

		# try to save keys to boot medium
		# ignore errors from this in case medium isn't writable
		( 
			cd /etc/ssh; 
			tar -cvf $MOUNTPOINT/ssh_keys.tar ssh_host_* 
		) || true
	fi

	log_action_end_msg $?
	;;

stop)
	;;
esac
EOF
chmod +x /etc/init.d/ssh-keys
insserv ssh-keys

# clean up apt package cache
apt-get clean

# set passwords for the 'root' and 'concerto' accounts.
# passwords are stored in passwords.sh
. ./passwords.sh
(echo $ROOT_PASSWORD; echo $ROOT_PASSWORD) | passwd root
(echo $USER_PASSWORD; echo $USER_PASSWORD) | passwd concerto
