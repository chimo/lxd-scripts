#!/bin/sh -e

name="${1}"

lxc exec "${name}" -- mkdir -p /etc/unbound/conf
lxc profile add "${name}" "${name}"

