#!/bin/sh

CHROOT_DIR=chroot
MIRROR_URL=http://ftp.us.debian.org/debian/

# create basic chroot
debootstrap wheezy $CHROOT_DIR $MIRROR_URL

# set up policy-rc.d so no daemons start in chroot
cat > $CHROOT_DIR/etc/policy-rc.d <<EOF
#!/bin/sh
exit 101
EOF
chmod +x $CHROOT_DIR/etc/policy-rc.d

# mount filesystems in the chroot
mount -t proc proc $CHROOT_DIR/proc
mount -t sysfs sysfs $CHROOT_DIR/sys

# run setup script inside chroot
cp chroot_tasks.sh $CHROOT_DIR
chmod +x $CHROOT_DIR/chroot_tasks.sh
chroot $CHROOT_DIR /chroot_tasks.sh

# unmount pseudo-filesystems
umount chroot/proc
umount chroot/sys

# delete temporary files created in chroot
rm $CHROOT_DIR/etc/policy-rc.d
rm $CHROOT_DIR/chroot_tasks.sh
