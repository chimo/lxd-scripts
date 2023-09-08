#!/bin/sh -e

# Paths
script_dir=$(dirname -- "$( readlink -f -- "$0"; )")
name="${1}"

# TODO: use xdg config path or wtv
lxc exec "${name}" -- mkdir -p /root/.config/newsboat

lxc profile add "${name}" "${name}"

