#!/bin/sh -e

name="${1}"

lxc exec "${name}" -- mkdir /root/chromic.org

lxc profile add "${name}" "${name}"

