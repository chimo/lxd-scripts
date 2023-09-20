#!/bin/sh -e

name="${1}"

script_dir=$(dirname -- "$( readlink -f -- "$0"; )")

lxc exec "${name}" -- mkdir -p /root/nextcloud /root/.config/Nextcloud/
lxc profile add "${name}" "${name}"
lxc file push "${script_dir}"/sync "${name}"/etc/periodic/15min/

