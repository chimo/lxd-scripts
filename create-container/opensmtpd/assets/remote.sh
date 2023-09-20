#!/bin/sh -e

# Install opensmtpd
apk add opensmtpd opensmtpd-openrc

# Firewall
nft add rule inet filter input ip saddr 10.118.161.0/24 tcp dport 2525 accept
nft -s list ruleset > /etc/nftables.nft

service nftables restart

service smtpd start
rc-update add smtpd

