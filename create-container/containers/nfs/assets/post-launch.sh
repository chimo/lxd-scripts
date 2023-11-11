#!/bin/sh -e

name="${1}"

lxc exec "${name}" -- mkdir -p /mnt/nfs

lxc profile add "${name}" "${name}"

