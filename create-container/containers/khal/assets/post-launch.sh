#!/bin/sh -eu

name="${1}"

lxc exec "${name}" -- mkdir -p /root/.config/khal /root/.calendars/
lxc profile add "${name}" "${name}"

