#!/bin/sh -eux

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
    lxc_project="${4}"

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

    lxc project switch "${lxc_project}"

    # Create container
    lxc launch "${image}" "${name}"

    # wait for network
    sleep 5s
)


configure_container() (
    # Params
    name="${1}"
    config_dir="${2}"
    types="${3}"

    # Paths
    script_dir=$(dirname -- "$( readlink -f -- "$0"; )")

    # Common post-launch commands
    lxc exec "${name}" -- sh < "${script_dir}/common/post-launch.sh"

    # "Types" post-launch commands
    if [ -n "${types}" ]; then
        run_post_launch "${name}" "${types}" "${script_dir}/types"
    fi

    # Container post-launch commands
    if [ -e "${config_dir}/assets/post-launch.sh" ]; then
        "${config_dir}/assets/post-launch.sh" "${name}"
    fi

    # "Types" post-config commands
    if [ -n "${types}" ]; then
        run_post_config "${name}" "${types}" "${script_dir}/types"
    fi

    # Container post-config commands
    if [ -e "${config_dir}/assets/remote.sh" ]; then
        lxc exec "${name}" -- sh < "${config_dir}/assets/remote.sh"
    fi
)


usage() (
    message=""
    newline="
"

    while IFS= read -r line
    do
        message="${message}${line}${newline}"
    done <<EOF
Usage: ${0} [-h] [-p] NAME
            [-h] [-p] -f [NAME]

options:
-h      show this help message and exit
-d      container settings directory
-p      lxc project
EOF

    echo "${message}" 1>&2
    exit 1
)


argparse() (
    config_dir=""
    lxc_project="default"

    while getopts ':d:p:' opt
    do
        case $opt in
            d)
                config_dir="${OPTARG-}"
                ;;
            p)
                lxc_project="${OPTARG-default}"
                ;;
            *)
                usage
                ;;
        esac
    done

    shift "$((OPTIND - 1))"

    name="${1-}"

    if [ -z "${config_dir}" ] && [ -z "${name}" ]; then
        usage
    fi

    main "${name}" "${config_dir}" "${lxc_project}"
)


main() (
    # Params
    name="${1}"
    config_dir="${2}"
    lxc_project="${3}"

    # Options
    image=""
    profiles=""

    # Define some paths
    script_dir=$(dirname -- "$( readlink -f -- "$0"; )")
    containers_dir="${script_dir}/containers"

    if [ -z "${config_dir}" ]; then
        config_dir="${containers_dir}/${name}"
    else
        config_dir=$(readlink -f -- "${config_dir}")
    fi

    config_file="${config_dir}/config"

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
        # or doing any other sort of sanitation...
        key="${line%=*}"
        value="${line#*=}"

        case $key in
            name)
                cname="${value}"
                ;;
            image)
                image="${value}"
                ;;
            profiles)
                profiles="${value}"
                ;;
            project)
                cproject="${value}"
                ;;
            *)
                echo "Invalid config key '${key}'"
                ;;
        esac
    done 3< "${config_file}"

    # If "name" wasn't passed as a parameter, use the value from the config
    # file
    if [ -z "${name}" ]; then
        name="${cname}"
    fi

    # If "project" wasn't passed as a parameter, use the value from the config
    # file
    if [ -z "${lxc_project}" ]; then
        lxc_project="${cproject}"
    fi

    if [ -z "${image}" ]; then
        echo "Config file must contain an 'image' property"
        exit 1
    fi

    create_container "${name}" "${image}" "${profiles}" "${lxc_project}"
    configure_container "${name}" "${config_dir}" "${profiles}"
)

argparse "${@}"

