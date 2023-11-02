#!/bin/sh -e

profile_exists() (
    profile="${1}"
    profile_exists=0

    if lxc profile show "${profile}" > /dev/null 2>&1; then
        profile_exists=1
    fi

    echo "${profile_exists}"
)


create_profile() (
    profile="${1}"
    basedir="${2}"

    lxc profile create "${profile}"
    lxc profile edit "${profile}" < "${basedir}/${profile}/assets/lxd.profile"
)


ensure_profiles_exist() (
    profiles="${1}"
    basedir="${2}"

    while IFS= read -r profile
    do
        if [ "$(profile_exists "${profile}")" -eq 0 ]; then
            create_profile "${profile}" "${basedir}"
        fi
    done<<EOF
$profiles
EOF
)


run_post_launch() (
    name="${1}"
    types="${2}"
    basedir="${3}"

    while IFS= read -r type
    do
        fullpath="${basedir}/${type}/assets/post-launch.sh"

        # The /dev/null is necessary otherwise the while loop breaks
        # after the first iteration. idk.
        # https://stackoverflow.com/a/13800476
        if [ -e "${fullpath}" ]; then
            "${fullpath}" "${name}" < /dev/null
        fi

        lxc profile add "${name}" "${type}"
    done<<EOF
$types
EOF
)


run_post_config() (
    name="${1}"
    types="${2}"
    basedir="${3}"

    while IFS= read -r type
    do
        fullpath="${basedir}/${type}/assets/remote.sh"

        if [ -e "${fullpath}" ]; then
            lxc exec "${name}" -- sh < "${fullpath}"
        fi
    done<<EOF
$types
EOF
)


create_container() (
    # Params
    name="${1}"
    image="${2}"
    types=$(echo "${3}" | tr ' ' '\n')

    # Define some paths
    script_dir=$(dirname -- "$( readlink -f -- "$0"; )")
    containers_dir="${script_dir}/containers"

    # Create profiles if they don't exist
    if [ -n "${types}" ]; then
        ensure_profiles_exist "${types}" "${script_dir}/types"
    fi

    # Create container-specific profile
    if [ -e "${containers_dir}/${name}/assets/lxd.profile" ]; then
        ensure_profiles_exist "${name}" "${containers_dir}"
    fi

    # Create container
    lxc launch "${image}" "${name}"

    # wait for network
    sleep 5s

    # Common post-launch commands
    lxc exec "${name}" -- sh < "${script_dir}/common/post-launch.sh"

    # "Types" post-launch commands
    if [ -n "${types}" ]; then
        run_post_launch "${name}" "${types}" "${script_dir}/types"
    fi

    # Container post-launch commands
    if [ -e "${containers_dir}/${name}/assets/post-launch.sh" ]; then
        "${containers_dir}/${name}/assets/post-launch.sh" "${name}"
    fi

    # "Types" post-config commands
    if [ -n "${types}" ]; then
        run_post_config "${name}" "${types}" "${script_dir}/types"
    fi

    # Container post-config commands
    if [ -e "${containers_dir}/${name}/assets/remote.sh" ]; then
        lxc exec "${name}" -- sh < "${containers_dir}/${name}/assets/remote.sh"
    fi
)


usage() (
    echo "Usage ${0} <name>" 1>&2
    exit 1
)


main() (
    if [ "${#}" -lt 1 ]; then
        usage
    fi

    # Params
    name="${1}"
    image=""
    profiles=""

    # Define some paths
    script_dir=$(dirname -- "$( readlink -f -- "$0"; )")
    containers_dir="${script_dir}/containers"
    config_file="${containers_dir}/${name}/config"

    if [ ! -f "${config_file}" ]; then
        echo "Config file ${config_file} doesn't exist"
        exit 1
    fi

    while IFS= read -r line <&3
    do
        # Skip blank lines
        if [ -z "${line}" ]; then
            continue
        fi

        # This is pretty unforgiving syntax-wise; we're not `trim`ing anything
        # or doing any other sort of sanitization...
        key="${line%=*}"
        value="${line#*=}"

        case $key in
            image)
                image="${value}"
            ;;
            profiles)
                profiles="${value}"
            ;;
            *)
                echo "Invalid config key '${key}'"
            ;;
        esac
    done 3< "${config_file}"

    if [ -z "${image}" ]; then
        echo "Config file must contain an 'image' property"
        exit 1
    fi

    create_container "${name}" "${image}" "${profiles}"
)

main "${@}"

