#!/bin/sh -eu

git -c 'versionsort.suffix=-' \
    ls-remote --exit-code --refs --sort='version:refname' \
    --tags https://git.alpinelinux.org/aports '*.*.*' \
    | grep -vE '[0-9]+\.[0-9]+_rc' \
    | tail -n 1 \
    | cut -d '/' -f3 \
    | grep -oE '[0-9]+\.[0-9]+'

