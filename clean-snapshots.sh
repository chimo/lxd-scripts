#!/bin/sh -e

get_containers() (
    containers=$(lxc list -c n --format csv)

    echo "${containers}"
)


get_snapshots() (
    container="${1}"

    snapshots=$(
        lxc query /1.0/instances/"${container}"/snapshots \
            | head -n -2 \
            | tail -n +2 \
            | tr -d '",'
    )

    echo "${snapshots}"
)


delete_snapshots() (
    container="${1}"
    snapshots="${2}"

    while IFS= read -r snapshot
    do
        snapshot_name="${snapshot##*/}"

        echo "Deleting ${container}/${snapshot_name}..."
        lxc delete "${container}/${snapshot_name}"
    done <<EOF
$snapshots
EOF

    echo ""
)


clean_snapshots() (
    containers="${1}"

    while IFS= read -r container
    do
        echo "Processing '${container}'..."

        snapshots=$(get_snapshots "${container}")
        nb_snapshots=$(echo "${snapshots}" | wc -l)

        if [ "${nb_snapshots}" -lt 2 ]; then
            echo "'${container}' has less than two snapshots. Skipping."
            echo ""
            continue
        fi

        # Remove the most recent snapshot from the list; we want to keep it.
        target_snapshots=$(echo "${snapshots}" | head -n -1)

        delete_snapshots "${container}" "${target_snapshots}"
    done <<EOF
$containers
EOF
)


main() (
    containers=$(get_containers)
    clean_snapshots "${containers}"
)

main

