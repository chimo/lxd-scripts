#!/bin/sh -e

# Install darkhttpd
apk add darkhttpd darkhttpd-openrc

rc-update add darkhttpd
service darkhttpd start

# Firewall
nft add rule inet filter input ip saddr 10.0.3.184 tcp dport 80 accept
nft -s list ruleset > /etc/nftables.nft

