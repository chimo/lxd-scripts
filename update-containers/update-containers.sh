#!/bin/sh -eu

LIBS_DIR=""

snapshot() (
    container="${1}"
    snapshot_name="pre-patch-$(date +%Y%m%d)"

    if ! lxc snapshot "${container}" "${snapshot_name}"; then
        echo "${container} failed to snapshot. Skipping upgrade..."
        return 1
    fi
)


update_running_containers() (
    containers=$(lxc list status=running -c n,config:image.os --format csv)

    while IFS= read -r container
    do
        name="${container%,*}"
        os="${container#*,}"

        handle "${restart}" "${snapshot}" "${name}" "${os}"
        echo ""
    done <<EOF
$containers
EOF
)


update_stopped_containers() (
    containers=$(lxc list status=stopped -c n,config:image.os --format csv)
    restart=0

    while IFS= read -r container
    do
        name="${container%,*}"
        os="${container#*,}"

        echo "Starting ${name}..."
        lxc start "${name}"

        handle "${restart}" "${snapshot}" "${name}" "${os}"

        echo "Stopping ${name}..."
        lxc stop "${name}"

        echo ""
    done <<EOF
$containers
EOF
)


update_specific() (
    restart="${1}"
    snapshot="${2}"
    containers="${3}"

    while IFS= read -r container
    do
        name="${container}"
        os=$(lxc list name="${name}" -c config:image.os --format csv)

        handle "${restart}" "${snapshot}" "${name}" "${os}"
    done <<EOF
$containers
EOF
)


usage() (
    message=""
    newline="
"

    while IFS= read -r line
    do
        message="${message}${line}${newline}"
    done <<EOF
Usage: ${0} [-a] [-h] [-P] [-R] [-S]

options:
-a      all containers (stopped containers will be started, upgraded and stopped)
-h      show this help message and exit
-P      do not run the post-upgrade script
-R      do not restart the container after upgrade
-S      do not snapshot the container before upgrade
EOF

    echo "${message}" 1>&2
    exit 1
)


argparse() (
    all_containers=0
    post_upgrade=1
    restart=1
    snapshot=1

    while getopts ':aPRS' opt
    do
        case $opt in
            a)
                all_containers=1
                ;;
            P)
                post_upgrade=0
                ;;
            R)
                restart=0
                ;;
            S)
                snapshot=0
                ;;
            *)
                usage
                ;;
        esac
    done

    shift "$((OPTIND - 1))"

    main "${post_upgrade}" "${restart}" "${snapshot}" "${all_containers}" "${*}"
)


normalize_os_name() (
    original_os="${1}"
    normalized_os=""

    case "${original_os}" in
        "Alpine"|"alpinelinux")
            normalized_os="alpine"
            ;;
        "Debian")
            normalized_os="debian"
            ;;
        *)
            ;;
    esac

    echo "${normalized_os}"
)


handle() (
    restart="${1}"
    take_snapshot="${2}"
    name="${3}"
    original_os="${4}"

    echo "Processing ${name}..."

    os=$(normalize_os_name "${original_os}")
    os_dir="${LIBS_DIR}/${os}"

    if [ ! -e "${os_dir}" ]; then
        echo "Unsupported OS"
        return 0
    fi

    # Check for updates
    nb_updates=$(lxc exec "${name}" -- sh < "${os_dir}/check-for-updates.sh")

    # Bail if no updates are pending
    if [ "${nb_updates}" -eq 0 ]; then
        echo "Nothing to do."
        return 0
    fi

    # Snapshot
    if [ "${take_snapshot}" -ne 0 ]; then
        echo "Snapshotting ${name}..."

        if ! snapshot "${name}"; then
            echo "Snapshot failed, skipping update"

            return 1
        fi
    fi

    # Update
    echo "Upgrading ${name}..."
    if ! lxc exec "${name}" -- sh < "${os_dir}/upgrade.sh" ; then
        echo "Upgrade failed"

        return 1
    fi

    # Restart
    if [ "${restart}" -ne 0 ]; then
        echo "Restarting ${name}..."
        lxc restart "${name}"
    fi
)


main() (
    # Params
    post_upgrade="${1}"
    restart="${2}"
    take_snapshot="${3}"
    all_containers="${4}"
    containers="${5}"

    # Paths
    main_dir=$(dirname -- "$( readlink -f -- "$0"; )")
    LIBS_DIR="${main_dir}/libs"
    config_file="${main_dir}/../config"

    # Source config file if it exists
    if [ -e "${config_file}" ]; then
        . "${config_file}"
    fi

    if [ -n "${containers}" ]; then
        containers=$(echo "${containers}" | tr ' ' '\n')
        update_specific "${restart}" "${take_snapshot}" "${containers}"
    else
        update_running_containers "${restart}" "${take_snapshot}"

        if [ "${all_containers}" -eq 1 ]; then
            update_stopped_containers "${take_snapshot}"
        fi
    fi

    # Run post-upgrade command
    if [ -n "${POST_UPGRADE_SCRIPT-}" ] && [ "${post_upgrade}" -ne 0 ]; then
        sh -c "${POST_UPGRADE_SCRIPT}"
    fi
)


argparse "${@}"

