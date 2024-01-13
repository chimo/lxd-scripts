#!/bin/sh -eu

LATEST_ALPINE_VERSION=""

get_latest_alpine_version() (
    if [ -z "${LATEST_ALPINE_VERSION}" ]; then
        LATEST_ALPINE_VERSION=$(
            git -c 'versionsort.suffix=-' \
                ls-remote --exit-code --refs --sort='version:refname' \
                --tags https://git.alpinelinux.org/aports '*.*.*' \
                | grep -vE '[0-9]+\.[0-9]+_rc' \
                | tail -n 1 \
                | cut -d '/' -f3 \
                | grep -oE '[0-9]+\.[0-9]+'
        )
    fi

    echo "${LATEST_ALPINE_VERSION}"
)


get_container_version() (
    container="${1}"
    cmd="grep 'VERSION_ID=' /etc/os-release | grep -oE '[0-9]+\.[0-9]+'"

    container_os_version=$(
        lxc exec "${container}" -- sh -c "${cmd}" < /dev/null
    )

    echo "${container_os_version}"
)


check_dist_upgrade() (
    container="${1}"
    latest_alpine_version=$(get_latest_alpine_version)
    container_os_version=$(get_container_version "${container}")

    needs_dist_upgrade=0

    if [ 1 -eq "$(echo "${latest_alpine_version} > ${container_os_version}" | bc)" ]; then
        needs_dist_upgrade=1
    fi

    echo "${needs_dist_upgrade}"
)


apk() (
    container="${1}"
    dist_upgrade="${2}"

    cmd="apk update && apk upgrade"

    echo "Upgrading ${name}..."
    lxc_exec "${container}" "${cmd}"

    if [ "${dist_upgrade}" -eq 1 ]; then
        needs_dist_upgrade=$(check_dist_upgrade "${container}")

        if [ "${needs_dist_upgrade}" -eq 0 ]; then
            echo "dist-upgrade not needed; running latest alpine."
            return 0
        fi

        latest_alpine_version=$(get_latest_alpine_version)

        # Change the repo URLs
        echo "Updating repo URLs..."
        change_repo_urls "${container}" "${latest_alpine_version}"

        # dist-upgrade
        cmd="apk update && apk upgrade -a"
        echo "Performing dist-upgrade..."
        lxc_exec "${container}" "${cmd}"
    fi
)


change_repo_urls() (
    name="${1}"
    latest_version="${2}"

    repo_file="/etc/apk/repositories"

    lxc exec "${name}" -- sh -c \
        "sed -i -E \"s#/alpine/v[0-9].[0-9]+/#/alpine/v${latest_version}/#g\" \
        \"${repo_file}\"" < /dev/null
)


apt() (
    container="${1}"
    dist_upgrade="${2}"

    cmd="apt update && apt upgrade -y"

    lxc_exec "${container}" "${cmd}"

    if [ "${dist_upgrade}" -eq 1 ]; then
        echo "dist-upgrade not implemented"
    fi
)


snapshot() (
    container="${1}"
    snapshot_name="pre-patch-$(date +%Y%m%d)"

    if ! lxc snapshot "${container}" "${snapshot_name}"; then
        echo "${container} failed to snapshot. Skipping upgrade..."
        return 1
    fi
)


lxc_exec() (
    name="${1}"
    cmd="${2}"

    if ! lxc exec "${name}" -- sh -c "${cmd}" < /dev/null; then
        return 1
    fi
)


check_for_updates() (
    name="${1}"
    os="${2}"

    case "${os}" in
        "Alpine"|"alpinelinux")
            lxc exec "${name}" -- sh -c "apk update -q" < /dev/null > /dev/null

            updates=$(
                lxc exec "${name}" -- sh -c "apk list -u | wc -l" < /dev/null
            )
            ;;
        "Debian")
            lxc exec "${name}" -- sh -c "apk update" < /dev/null > /dev/null

            updates=$(
                lxc exec "${name}" -- sh -c "apk list --upgradable" < /dev/null
            )
            ;;
        *)
            ;;
    esac

    echo "${updates}"
)


update() (
    name="${1}"
    os="${2}"
    dist_upgrade="${3}"

    case "${os}" in
        "Alpine"|"alpinelinux")
            apk "${name}" "${dist_upgrade}"
            ;;
        "Debian")
            apt "${name}" "${dist_upgrade}"
            ;;
        *)
            echo "Unknown OS: ${os}"
            ;;
    esac
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
Usage: ${0} [-a] [-d] [-h] [-P] [-R] [-S]

options:
-a      all containers (stopped containers will be started, upgraded and stopped)
-d      perform a "dist-upgrade"
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


handle() (
    restart="${1}"
    take_snapshot="${2}"
    name="${3}"
    os="${4}"
    dist_upgrade="${4}"

    echo "Processing ${name}..."

    # Check for updates
    nb_updates=$(check_for_updates "${name}" "${os}")

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
    if ! update "${name}" "${os}" "${dist_upgrade}"; then
        echo "Update failed"

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
    dist_upgrade="${5}"
    containers="${6}"

    # Paths
    main_dir=$(dirname -- "$( readlink -f -- "$0"; )")
    config_file="${main_dir}/config"

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

