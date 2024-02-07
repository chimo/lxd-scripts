#!/bin/sh -eu

name="${1}"

lxc exec "${name}" -- mkdir -p /root/screenshots
lxc profile add "${name}" "${name}"

