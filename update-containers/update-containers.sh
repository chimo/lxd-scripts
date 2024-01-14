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


check_dist_upgrade() (
    container="${1}"
    os="${2}"
    latest_os_version="${3}"

    os_dir="${LIBS_DIR}/${os}"

    container_os_version=$(lxc exec "${name}" -- sh < "${os_dir}/container-os-version.sh")

    needs_dist_upgrade=0

    if [ 1 -eq "$(echo "${latest_os_version} > ${container_os_version}" | bc)" ]; then
        needs_dist_upgrade=1
    fi

    echo "${needs_dist_upgrade}"
)


update_running_containers() (
    restart=${1}
    snapshot="${2}"
    dist_upgrade="${3}"

    containers=$(lxc list status=running -c n,config:image.os --format csv)

    while IFS= read -r container
    do
        name="${container%,*}"
        os="${container#*,}"

        handle "${restart}" "${snapshot}" "${name}" "${os}" "${dist_upgrade}"
        echo ""
    done <<EOF
$containers
EOF
)


update_stopped_containers() (
    restart=0
    snapshot="${1}"
    dist_upgrade="${2}"

    containers=$(lxc list status=stopped -c n,config:image.os --format csv)

    while IFS= read -r container
    do
        name="${container%,*}"
        os="${container#*,}"

        echo "Starting ${name}..."
        lxc start "${name}"

        handle "${restart}" "${snapshot}" "${name}" "${os}" "${dist_upgrade}"

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
    dist_upgrade="${3}"
    containers="${4}"

    while IFS= read -r container
    do
        name="${container}"
        os=$(lxc list name="${name}" -c config:image.os --format csv)

        handle "${restart}" "${snapshot}" "${name}" "${os}" "${dist_upgrade}"
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
    dist_upgrade=0
    post_upgrade=1
    restart=1
    snapshot=1

    while getopts ':adPRS' opt
    do
        case $opt in
            a)
                all_containers=1
                ;;
            d)
                dist_upgrade=1
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

    main "${post_upgrade}" "${restart}" "${snapshot}" "${all_containers}" \
         "${dist_upgrade}" "${*}"
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
    dist_upgrade="${5}"

    echo "Processing ${name}..."

    os=$(normalize_os_name "${original_os}")
    os_dir="${LIBS_DIR}/${os}"

    if [ ! -e "${os_dir}" ]; then
        echo "Unsupported OS"
        return 0
    fi

    # Check for updates
    echo "Checking for updates..."
    nb_updates=$(lxc exec "${name}" -- sh < "${os_dir}/check-for-updates.sh")

    if [ "${nb_updates}" -eq 0 ]; then
        echo "No updates available."
    fi

    has_dist_upgrade=0
    if [ "${dist_upgrade}" -eq 1 ]; then
        echo "Checking if dist-upgrade available..."

        # TODO: can we cache this so we don't check for every container?
        latest_os_version=$("${os_dir}/latest-os-version.sh")
        has_dist_upgrade=$(check_dist_upgrade "${name}" "${os}" "${latest_os_version}")

        if [ "${has_dist_upgrade}" -eq 0 ]; then
            echo "No dist-upgrade available."
        fi
    fi

    if [ "${nb_updates}" -eq 0 ] && [ "${has_dist_upgrade}" -eq 0 ]; then
        echo "Nothing to do."
        return 0
    fi

    # Snapshot; we're either doing upgrades or dist-upgrade
    if [ "${take_snapshot}" -ne 0 ]; then
        echo "Snapshotting ${name}..."

        if ! snapshot "${name}"; then
            echo "Snapshot failed, aborting."

            return 1
        fi
    fi

    if [ "${has_dist_upgrade}" -eq 1 ]; then
        echo "Dist-upgrading ${name}..."

        if ! lxc exec --env LATEST_OS_VERSION="${latest_os_version}" "${name}" -- sh < "${os_dir}/dist-upgrade.sh" ; then
            echo "Dist-upgrade failed."

            return 1
        fi
    else
        echo "Upgrading ${name}..."
        if ! lxc exec "${name}" -- sh < "${os_dir}/upgrade.sh" ; then
            echo "Upgrade failed."

            return 1
        fi
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
    dist_upgrade="${5}"
    containers="${6}"

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
        update_specific "${restart}" "${take_snapshot}" "${dist_upgrade}" "${containers}"
    else
        update_running_containers "${restart}" "${take_snapshot}" "${dist_upgrade}"

        if [ "${all_containers}" -eq 1 ]; then
            update_stopped_containers "${take_snapshot}" "${dist_upgrade}"
        fi
    fi

    # Run post-upgrade command
    if [ -n "${POST_UPGRADE_SCRIPT-}" ] && [ "${post_upgrade}" -ne 0 ]; then
        sh -c "${POST_UPGRADE_SCRIPT}"
    fi
)


argparse "${@}"

