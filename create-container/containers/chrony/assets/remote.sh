#!/bin/sh -eu

# Configure firewall
nft add rule inet filter input ip saddr 192.168.10.0/24 udp dport 123 accept
nft -s list ruleset > /etc/nftables.nft

# Start and enable chrony at boot
service chronyd start
rc-update add chronyd

