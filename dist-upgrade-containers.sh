#!/bin/sh -eu

LATEST_ALPINE_VERSION=""

dist_upgrade_specific() (
    containers="${1}"
    update_script="${main_dir}/update-containers.sh"

    while IFS= read -r container
    do
        # Snapshot, update, no-restart, no post-upgrade
        echo "Updating..."
        "${update_script}" -P -R "${container}" > /dev/null

        # Dist-upgrade
        dist_upgrade "${container}"

        # Restart
        lxc restart "${container}"
    done <<EOF
$containers
EOF
)


handle() (
    container="${1}"
    os="${2}"

    echo "Processing ${container}..."
    echo "Snapshotting ${container}..."
    snapshot "${container}"

    case "${os}" in
        "Alpine"|"alpinelinux")
            apk "${container}"
            ;;
        "Debian")
            apt "${container}"
            ;;
        *)
            echo "Unknown OS: ${os}"
            ;;
    esac
)


dist_upgrade_all() (
    containers=$(lxc list status=running -c n,config:image.os --format csv)

    while IFS= read -r container
    do
        name="${container%,*}"
        os="${container#*,}"

        handle "${name}" "${os}"
        echo ""
    done <<EOF
$containers
EOF
)


dist_upgrade() (
    container="${1}"
    os=$(lxc list name="${container}" -c config:image.os --format csv)

    handle "${container}" "${os}"
)


snapshot() (
    container="${1}"
    snapshot_name="pre-dist-upgrade-$(date +%Y%m%d)"

    if ! lxc snapshot "${container}" "${snapshot_name}"; then
        echo "${container} failed to snapshot. Skipping upgrade..."
        return 1
    fi
)


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


apt() (
    echo "TODO"
)


change_repo_urls() (
    name="${1}"
    latest_version="${2}"

    repo_file="/etc/apk/repositories"

    lxc exec "${name}" -- sh -c \
        "sed -i -E \"s#/alpine/v[0-9].[0-9]+/#/alpine/v${latest_version}/#g\" \
        \"${repo_file}\"" < /dev/null
)


apk() (
    name="${1}"
    needs_dist_upgrade=$(check_dist_upgrade "${name}")

    echo "Processing ${name}..."

    if [ "${needs_dist_upgrade}" -eq 0 ]; then
        echo "Nothing to do."
        return 0
    fi

    latest_alpine_version=$(get_latest_alpine_version)

    # Change repo URLs
    echo "Updating repo URLs..."
    change_repo_urls "${name}" "${latest_alpine_version}"

    # Update
    echo "Updating..."
    lxc exec "${name}" -- sh -c "apk update -q" < /dev/null

    # Upgrade
    echo "Upgrading..."
    lxc exec "${name}" -- sh -c "apk upgrade -a" < /dev/null
)


usage() (
    message=""
    newline="
"

    while IFS= read -r line
    do
        message="${message}${line}${newline}"
    done <<EOF
Usage: ${0} [-h]

options:
-h      show this help message and exit
EOF

    echo "${message}" 1>&2
    exit 1
)


argparse() (
    while getopts ':' opt
    do
        case $opt in
            *)
                usage
                ;;
        esac
    done

    shift "$((OPTIND - 1))"

    main "${*}"
)


main() (
    # Params
    containers="${1-}" # Default to empty string if undefined

    # Paths
    main_dir=$(dirname -- "$( readlink -f -- "$0"; )")
    config_file="${main_dir}/config"

    # Source config file if it exists
    if [ -e "${config_file}" ]; then
        . "${config_file}"
    fi

    # Upgrade
    if [ -n "${containers}" ]; then
        containers=$(echo "${@}" | tr ' ' '\n')

        dist_upgrade_specific "${containers}"
    else
        dist_upgrade_all
    fi

    # Run post-upgrade command
    if [ -n "${POST_UPGRADE_SCRIPT}" ]; then
        sh -c "${POST_UPGRADE_SCRIPT}"
    fi
)


main "${@}"

