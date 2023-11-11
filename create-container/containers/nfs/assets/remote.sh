#!/bin/sh -e

# Install nfs
apk add nfs-utils

# Prep nfs mountpoints
mkdir -p /srv/nfs/movies \
    /srv/nfs/tv

# Configure fstab
fstab="
/mnt/nfs/media/movies /srv/nfs/movies  none   bind,nofail   0   0
/mnt/nfs/media/tv /srv/nfs/tv  none   bind,nofail   0   0
"

cat "${fstab}" >> /etc/fstab

# Mount all-the-things
mount -a

nfs_exports="
/srv/nfs/          192.168.10.0/24(rw,sync,crossmnt,fsid=0,no_subtree_check)
/srv/nfs/movies    192.168.10.0/24(rw,sync)
/srv/nfs/tv        192.168.10.0/24(rw,sync)
"

cat "${nfs_exports}" >> /etc/exports

# nfs service
rc-update add nfs
service nfs start

