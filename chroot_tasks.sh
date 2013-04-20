# set up variables so that config prompts are not displayed
export LC_ALL="C"
export LANGUAGE="C"
export LANG="C"
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# install packages we need (build-essential is temporary)
apt-get -y install xserver-xorg xserver-xorg-video-all \
	chromium unclutter ifplugd xinit blackbox \
	ruby1.9.1-full build-essential

# and rubygems we need
gem install bandshell

# once rubygems have been installed, build-essential isn't needed
apt-get -y purge build-essential
apt-get -y autoremove

# install live-boot so we get an initrd built for us
apt-get -y install live-boot live-boot-initramfs-tools linux-image-amd64

# set up hostname
echo concerto-player > /etc/hostname

# create a user account that, when logged in, 
# will start the X server and the player
useradd -m -s `which xinit` concerto

# create a .xinitrc that will start fullscreen chromium
cat > /home/concerto/.xinitrc << EOF
#!/bin/sh
# start window manager
blackbox &

# hide the mouse pointer
unclutter &

# run the browser (if it crashes or dies, the X session should end)
chromium --no-first-run --kiosk http://nightly.concerto-signage.org/frontend/1
EOF

# modify inittab so we auto-login at boot as concerto
sed -i -e 's/getty 38400 tty2/getty -a concerto tty2/' /etc/inittab

# set up a root password
ROOT_PASSWORD=phuphek9
(echo $ROOT_PASSWORD; echo $ROOT_PASSWORD) | passwd root

USER_PASSWORD=blah
(echo $USER_PASSWORD; echo $USER_PASSWORD) | passwd concerto
