#!/bin/sh -e

apk() (
    container="${1}"
    cmd="apk list -u"

    _exec "${container}" "${cmd}"
)


apt() (
    container="${1}"
    cmd="apk list --upgradable"

    _exec "${container}" "${cmd}"
)


_exec() (
    container="${1}"
    cmd="${2}"

    updates=$(lxc exec "${container}" -- sh -c "${cmd}" < /dev/null)

    if [ -n "${updates}" ]; then
        echo "${container}"
        echo "${updates}"
    fi
)


main() (
    containers=$(lxc list status=running -c n,config:image.os --format csv)

    while IFS= read -r container
    do
        name="${container%,*}"
        os="${container#*,}"

        case "${os}" in
            "Alpine")
                apk "${name}"
                ;;
            "Debian")
                apt "${name}"
                ;;
            *)
                echo "Unknown OS: ${os}"
                ;;
        esac

        echo ""
    done <<EOF
$containers
EOF
)


main

