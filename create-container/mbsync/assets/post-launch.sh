#!/bin/sh -e

name="${1}"

lxc exec "${name}" -- mkdir -p /root/mail /root/.config/mbsync
lxc profile add "${name}" "${name}"

