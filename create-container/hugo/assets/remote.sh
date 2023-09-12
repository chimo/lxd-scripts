#!/bin/sh -e

# Install hugo
apk add hugo

# Firewall
nft add rule inet filter input ip saddr 10.118.161.0/24 tcp dport 1313 accept
nft -s list ruleset > /etc/nftables.nft

