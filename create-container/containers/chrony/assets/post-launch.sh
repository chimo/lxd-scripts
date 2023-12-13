#!/bin/sh -eu

# Params
name="${1}"

# Define some paths
script_dir=$(dirname -- "$( readlink -f -- "$0"; )")
config_file="${script_dir}/chrony.conf"
confd_file="${script_dir}/chronyd"

# Install and configure chrony
lxc exec "${name}" -- apk add chrony
lxc file push "${config_file}" "${name}/etc/chrony/chrony.conf"
lxc file push "${confd_file}" "${name}/etc/conf.d/chronyd"

