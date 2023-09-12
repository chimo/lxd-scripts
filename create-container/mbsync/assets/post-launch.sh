#!/bin/sh -e

name="${1}"

script_dir=$(dirname -- "$( readlink -f -- "$0"; )")

lxc exec "${name}" -- mkdir -p /root/mail /root/.config/mbsync
lxc profile add "${name}" "${name}"
lxc file push "${script_dir}"/refresh_mail "${name}"/etc/periodic/15min/

