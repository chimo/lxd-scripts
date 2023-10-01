#!/bin/sh -e

# signal-desktop is only on edge testing repo
sed -i 's/v[0-9]\.[0-9][0-9]/edge/g' /etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# Upgrade
apk update
apk upgrade

# Install
apk add signal-desktop

