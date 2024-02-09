#!/bin/sh -eu

name="${1}"

lxc exec "${name}" -- mkdir -p /root/.vdirsyncer/status/ /root/.calendars/
lxc profile add "${name}" "${name}"

