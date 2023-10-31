#!/bin/sh -e

apk() (
    container="${1}"
    cmd="apk version -l '<' | tail -n +2"

    # 3.18.3-r0
    version_format="[0-9]+\.[0-9]+\.[0-9]+-r[0-9]+"

    results=$(_exec "${container}" "${cmd}")

    if [ -n "${results}" ]; then
        output='['

        # alpine-base-3.18.3-r0 < 3.18.4-r0 
        while IFS= read -r line
        do
            # alpine-base-3.18.3-r0 
            installed_info=$(echo "${line}" | awk '{print $1}')

            # 3.18.3-r0
            local_version=$(
                echo "${installed_info}" | grep -oE ${version_format}
            )

            # alpine-base
            pkg_name=$(echo "${installed_info}" | sed "s/-${current_version}//")

            # 3.18.4-r0
            latest_version=$(echo "${line}" | awk '{print $3}')

            item=$(
                printf '{"package_name": "%s", "local_version": "%s", "latest_version": "%s"}' \
                    "${pkg_name}" \
                    "${local_version}"\
                    "${latest_version}"
            )

            output="${output}${item},"
        done <<EOF
$results
EOF
        # Remove trailing comma
        output="${output%,*}"

        # Close array
        output="${output}]"

        echo "${output}"
    else
        echo "[]"
    fi
)


apt() (
    container="${1}"
    cmd="apt list --upgradable | tail -n +2"

    output=$(
        _exec "${container}" "${cmd}" \
        | awk '{printf "%s\\n", $0}' # Replace newlines with literal "\n"
    )

    printf '"%s"' "${output}"
)


_exec() (
    container="${1}"
    cmd="${2}"

    updates=$(lxc exec "${container}" -- sh -c "${cmd}" < /dev/null)

    if [ -n "${updates}" ]; then
        echo "${updates}"
    fi
)


main() (
    containers=$(lxc list status=running -c n,config:image.os --format csv)

    # Start array
    output='['

    while IFS= read -r container
    do
        name="${container%,*}"
        os="${container#*,}"

        case "${os}" in
            "Alpine"|"alpinelinux")
                results=$(apk "${name}")
                ;;
            "Debian")
                results=$(apt "${name}")
                ;;
            *)
                results="Unknown OS: ${os}"
                ;;
        esac

        if [ -n "${results}" ]; then

            updates="${results}"

            mac=$(lxc list -c volatile.eth0.hwaddr --format csv "${name}")

            # Note: this doesn't guarantee valid JSON (ex: if output has a
            #       double-quote in it.
            json_updates=$(
                printf '{"name": "%s", "mac": "%s", "updates": %s}' \
                    "${name}" \
                    "${mac}" \
                    "${updates}"
            )

            # Append to array
            output="${output}${json_updates},"
        fi
    done <<EOF
$containers
EOF

    # Remove trailing comma
    output="${output%,*}"

    # Close array
    output="${output}]"

    # Print
    echo "${output}"
)


main "${@}"

