#!/bin/sh -e

name="${1}"

lxc exec "${name}" -- mkdir -p /root/.config/mpv

lxc profile add "${name}" "${name}"

