#!/bin/sh

# FIXME(feyu): using the label during init apparently doesn't work.
# Use /dev/vdb for now.
# /bin/mount /dev/disk/by-label/overlay /overlay

ls /dev/disk/by-label
/bin/mount /dev/vdb /overlay

mkdir -p /overlay/root /overlay/work /overlay/root/rom

/bin/mount \
    -o noatime,lowerdir=/,upperdir=/overlay/root,workdir=/overlay/work \
    -t overlay "overlayfs:/overlay/root" /merged

/usr/sbin/pivot_root /merged /merged/rom

# remove dirs for setting up the overlay from the new root
rmdir /overlay
rmdir /merged

exec /usr/sbin/init $@
