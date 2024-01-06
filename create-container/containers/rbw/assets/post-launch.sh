#!/bin/sh -eu

name="${1}"

lxc exec "${name}" -- mkdir -p /root/.config/rbw
lxc profile add "${name}" "${name}"

