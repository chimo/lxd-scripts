description: nfs profile
config:
  # Map uid so that the container's root user can rwx the shared folders
  # The "root" user in the container will look like our user 1000 on the host
  # Note: needs "root:1000:1" in /etc/subuid
  raw.idmap: uid 1000 0
devices:
  nfs:
    path: /mnt/nfs
    source: /mnt/nfs
    type: disk
name: nfs

