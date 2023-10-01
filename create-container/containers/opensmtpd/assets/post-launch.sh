#!/bin/sh -e

name="${1}"

lxc exec "${name}" -- mkdir /etc/smtpd

lxc profile add "${name}" "${name}"

