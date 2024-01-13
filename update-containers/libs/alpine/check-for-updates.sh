#!/bin/sh -eu

apk update -q > /dev/null
apk list -u | wc -l

