# This file can be used to apply customizations to the disk image
# as it's being created. $MOUNTPOINT is the root of the mounted
# disk image. Note that this is NOT the same as the live filesystem.
# $MOUNTPOINT corresponds to /lib/live/mount/medium in the running player.

# generate a xrandr.sh file for custom xrandr commands

# cat > $MOUNTPOINT/xrandr.sh << EOF
# #!/bin/bash
# .....
# EOF

# set default Concerto URL

# mkdir -p $MOUNTPOINT/concerto/config
# echo -en "http://example.com/path/to/concerto" > $MOUNTPOINT/concerto/config/concerto_url

