#!/bin/sh -e

name="${1}"

lxc exec "${name}" -- sh -c 'install -D -d -m0700 /tmp/1000-runtime-dir'

