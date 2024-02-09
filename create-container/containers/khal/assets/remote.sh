#!/bin/sh -eu

# Install
apk add khal tzdata

# Set timezone
ln -s /usr/share/zoneinfo/America/Toronto /etc/localtime

