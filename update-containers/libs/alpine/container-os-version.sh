#!/bin/sh -eu

grep 'VERSION_ID=' /etc/os-release | grep -oE '[0-9]+\.[0-9]+'

