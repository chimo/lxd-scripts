#!/bin/sh -e

# Paths
script_dir=$(dirname -- "$( readlink -f -- "$0"; )")
name="${1}"

lxc file push ${script_dir}/link-wayland-socket "${name}"/etc/init.d/
lxc exec "${name}" -- sh -c 'chmod 755 /etc/init.d/link-wayland-socket'
lxc exec "${name}" -- mkdir -p /mnt/wayland1

