#!/bin/sh -eu

latest_alpine_version="${LATEST_OS_VERSION}"

# Upgrade
apk update && apk upgrade

# Update repo URLs
sed -i -E "s#/alpine/v[0-9].[0-9]+/#/alpine/v${latest_alpine_version}/#g" \
        /etc/apk/repositories

# Dist-upgrade
apk update && apk upgrade -a

