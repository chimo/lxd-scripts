#!/bin/sh -e

# Custom service to create symlink on boot
service link-wayland-socket start
rc-update add link-wayland-socket

# We'll probably want at least one font...
apk add font-dejavu

