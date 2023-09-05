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


main() (
    name="${1}"
    shift
    types=$(echo "${@}" | tr ' ' '\n')

    # Define some paths
    script_dir=$(dirname -- "$( readlink -f -- "$0"; )")

    # Create profiles if they don't exist
    ensure_profiles_exist "${types}" "${script_dir}/types"

    # Create container
    lxc launch images:alpine/3.18/amd64 "${name}"

    # wait for network
    sleep 5s

    # Common post-launch commands
    lxc exec "${name}" -- sh < "${script_dir}/common/post-launch.sh"

    # "Types" post-launch commands
    run_post_launch "${name}" "${types}" "${script_dir}/types"

    # Container post-launch commands
    if [ -e "${script_dir}/${name}/assets/post-launch.sh" ]; then
        "${script_dir}/${name}/assets/post-launch.sh" "${name}"
    fi

    # "Types" post-config commands
    run_post_config "${name}" "${types}" "${script_dir}/types"

    # Container post-config commands
    if [ -e "${script_dir}/${name}/assets/remote.sh" ]; then
        lxc exec "${name}" -- sh < "${script_dir}/${name}/assets/remote.sh"
    fi
)


main "${@}"

