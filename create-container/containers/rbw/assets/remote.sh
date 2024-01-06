#!/bin/sh -eu

# Testing repo
echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# Install
apk add rbw pinentry-tty

