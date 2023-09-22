#!/bin/sh -e

name="${1}"

lxc exec "${name}" -- mkdir -p /root/.irssi

lxc profile add "${name}" "${name}"

