#!/bin/sh -e

if [ "`whoami`" != "root" ]; then
	# check if sudo is available, if not error out
	if command -v sudo >/dev/null 2>&1; then
		echo This script needs root privileges to run.
		echo Press enter to attempt to run under sudo.
		echo Press ctrl-C to quit.
		read dummyvar
		exec sudo $0
	else
		echo This script needs root privileges to run.
		exit 1
	fi
fi

OUTFILE=concerto-uefi.img

# Create a 1024MB image and create two partitions.
# The first is the EFI System partition, the second will contain the
# concerto files.
dd if=/dev/zero of=$OUTFILE bs=1M count=1 seek=1023
LOOP_DEV=`losetup --show -f $OUTFILE`

# Now we've got an image and a loopback device. Let's partition it.
# We'll create a 32MB EFI system partition and use the rest for
# the Concerto image. We'll stick with MBR for now because that
# gives us the best shot of having this bootable on all types
# of systems.
#
# First line ,32,ef means start the partition at the first free
# location (the beginning of the image), size it 32MB, and assign
# it type 0xef (EFI system).
#
# Second line ,,0c,* means start the second partition at the end
# of the first one, fill the rest of the image with it, and assign
# it type 0x0c (FAT32 LBA).
sfdisk -uM $LOOP_DEV << 'EOF'
,32,ef,*
,,0c
;
;
EOF

EFI_PARTITION_NO="p1"
PARTITION_NO="p2"
EFI_PARTITION=$LOOP_DEV$EFI_PARTITION_NO
PARTITION=$LOOP_DEV$PARTITION_NO
CHROOT_DIR=chroot
partx -a $LOOP_DEV

mkdosfs $EFI_PARTITION
mkdosfs -F 32 $PARTITION

# install (BIOS) syslinux bootloader
syslinux -i $PARTITION

# generate mountpoints for the two partitions
TMP_DIR="/tmp"
RAND_NAME=`head -c512 /dev/urandom | md5sum | head -c8`
MOUNTPOINT=$TMP_DIR/$RAND_NAME
RAND_NAME=`head -c512 /dev/urandom | md5sum | head -c8`
EFI_MOUNTPOINT=$TMP_DIR/$RAND_NAME
mkdir $MOUNTPOINT $EFI_MOUNTPOINT

# mount partitions so we can copy files over
mount $PARTITION $MOUNTPOINT
mount $EFI_PARTITION $EFI_MOUNTPOINT

# install EFI bootloader
mkdir -p $EFI_MOUNTPOINT/EFI/BOOT
cp /usr/lib/SYSLINUX.EFI/efi64/* $EFI_MOUNTPOINT/EFI/BOOT
cp /usr/lib/syslinux/modules/efi64/* $EFI_MOUNTPOINT/EFI/BOOT
cp $EFI_MOUNTPOINT/EFI/BOOT/syslinux.efi $EFI_MOUNTPOINT/EFI/BOOT/BOOTx64.EFI

# create squashfs filesystem
mkdir $MOUNTPOINT/live
mksquashfs $CHROOT_DIR $MOUNTPOINT/live/concerto.squashfs

# copy other needed files from chroot into boot medium

# There should only be one kernel/initrd.img pair. So we just find it and copy it.
KERNEL=`ls $CHROOT_DIR/boot | grep vmlinuz | head -1`
INITRD=`ls $CHROOT_DIR/boot | grep initrd.img | head -1`

# Copy kernel and generate BIOS syslinux config.
cp $CHROOT_DIR/boot/$KERNEL $CHROOT_DIR/boot/$INITRD $MOUNTPOINT 
cat > $MOUNTPOINT/syslinux.cfg <<EOF
DEFAULT concerto
LABEL concerto
KERNEL $KERNEL
INITRD $INITRD
APPEND boot=live 
EOF

# Now we do the same thing on the EFI side.
cp $CHROOT_DIR/boot/$KERNEL $CHROOT_DIR/boot/$INITRD $EFI_MOUNTPOINT
cat > $EFI_MOUNTPOINT/EFI/BOOT/syslinux.cfg <<EOF
DEFAULT concerto
LABEL concerto
KERNEL ../../$KERNEL
INITRD ../../$INITRD
APPEND boot=live 
EOF

source localconfig.sh

# clean up after ourselves
sleep 1
umount $MOUNTPOINT
rmdir $MOUNTPOINT
umount $EFI_MOUNTPOINT
rmdir $EFI_MOUNTPOINT
partx -d $LOOP_DEV
losetup -d $LOOP_DEV
