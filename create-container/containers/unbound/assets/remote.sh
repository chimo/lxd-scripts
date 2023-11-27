#!/bin/sh -e

# Install
apk add unbound

# Start and enable daemon
service unbound start
rc-update add unbound

# Firewall
nft add rule inet filter input ip saddr 192.168.20.0/24 udp dport 53 accept
nft -s list ruleset > /etc/nftables.nft

service nftables restart

