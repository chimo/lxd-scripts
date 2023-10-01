#!/bin/sh -e

apk() (
    container="${1}"

    lxc exec "${container}" -- sh -c "apk update -q" < /dev/null

    updates=$(
        lxc exec "${container}" -- sh -c "apk list -u | wc -l" < /dev/null
    )

    if [ "${updates}" -gt 0 ]; then
        cmd="apk upgrade"
        upgrade "${container}" "${cmd}"
    else
        echo "Nothing to do..."
    fi
)


apt() (
    container="${1}"
    cmd="apt update && apt upgrade -y"

    upgrade "${container}" "${cmd}"
)


snapshot() (
    container="${1}"
    snapshot_name="pre-patch-$(date +%Y%m%d)"

    echo "Snapshotting ${container}..."

    if ! lxc snapshot "${name}" "${snapshot_name}"; then
        echo "${container} failed to snapshot. Skipping upgrade..."
        return
    fi
)


_upgrade() (
    container="${1}"
    cmd="${2}"

    echo "Upgrading ${container}..."

    if ! lxc exec "${container}" -- sh -c "${cmd}" < /dev/null; then
        echo "Upgrade failed"
        return
    fi
)


upgrade() (
    container="${1}"
    cmd="${2}"

    if ! snapshot "${container}"; then
        echo "Snapshot failed, skipping upgrade..."
    else
        _upgrade "${container}" "${cmd}"
    fi

    echo "Restarting ${container}..."
    lxc restart "${container}"
)


update() (
    name="${1}"
    os="${2}"

    echo "Processing ${name}..."

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
)


update_all() (
    containers=$(lxc list status=running -c n,config:image.os --format csv)

    while IFS= read -r container
    do
        name="${container%,*}"
        os="${container#*,}"

        update "${name}" "${os}"
    done <<EOF
$containers
EOF
)


update_specific() (
    containers="${1}"

    while IFS= read -r container
    do
        name="${container}"
        os=$(lxc list name="${name}" -c config:image.os --format csv)

        update "${name}" "${os}"
    done <<EOF
$containers
EOF
)


main() (
    if [ "${1}" = "--containers" ]; then
        shift
        containers=$(echo "${@}" | tr ' ' '\n')

        update_specific "${containers}"
    else
        update_all
    fi
)


main "${@}"

