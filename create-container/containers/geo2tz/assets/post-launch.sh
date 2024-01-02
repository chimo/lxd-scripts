#!/bin/sh -eu

name="${1}"

script_dir=$(dirname -- "$( readlink -f -- "$0"; )")

lxc profile add "${name}" "${name}"

# stunnel stuff
lxc exec "${name}" -- sh -c "apk add stunnel"
lxc file push "${script_dir}"/stunnel.conf "${name}"/etc/stunnel/
lxc exec "${name}" -- sh -c "touch /var/log/stunnel.log"
lxc exec "${name}" -- sh -c "chown stunnel:stunnel /var/log/stunnel.log"
lxc exec "${name}" -- sh -c "service stunnel start"
lxc exec "${name}" -- sh -c "rc-update add stunnel"


