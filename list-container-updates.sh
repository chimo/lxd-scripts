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
    names_only=0

    if [ "${1}" = "--names-only" ]; then
        names_only=1
    fi

    while IFS= read -r container
    do
        name="${container%,*}"
        os="${container#*,}"

        case "${os}" in
            "Alpine")
                results=$(apk "${name}")
                ;;
            "Debian")
                results=$(apt "${name}")
                ;;
            *)
                echo "Unknown OS: ${os}"
                ;;
        esac

        if [ -n "${results}" ]; then
            if [ "${names_only}" -eq 0 ]; then
                echo "${results}"
                echo ""
            else
                echo "${results}" | head -n 1
            fi
        fi
    done <<EOF
$containers
EOF
)


main "${@}"

