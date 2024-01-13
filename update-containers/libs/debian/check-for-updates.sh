#!/bin/sh -eu

apt update > /dev/null
apt list --upgradable | wc -l

