#!/bin/sh -eu

# Append with custom repo
echo "http://pkgs.lxc.chromic.org/chromic" >> /etc/apk/repositories

# Signing key
wget -q -O /etc/apk/keys/alpine@lxc.chromic.org.rsa.pub \
    http://pkgs.lxc.chromic.org/chromic/alpine@lxc.chromic.org.rsa.pub

# Install
apk update
apk add geo2tz

# Firewall
nft add rule inet filter input ip saddr haproxy.lxc.chromic.org tcp dport 443 accept
nft -s list ruleset > /etc/nftables.nft

service nftables restart

