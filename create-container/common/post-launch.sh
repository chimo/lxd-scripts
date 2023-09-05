#!/bin/sh -e

# nftables everywhere
apk add nftables
service nftables start
rc-update add nftables

