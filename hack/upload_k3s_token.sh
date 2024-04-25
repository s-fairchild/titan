#!/bin/bash

set -o nounset \
    -o errexit

main() {
    local -r remote_alias="$1"
    local -r ssh_id="$2"

    if [ "$ssh_id" == "remove" ]; then
        remove_connection remote_alias
        exit 0
    fi

    local -r remote_ip="$3"
    local token
    generate_token token

    if ! podman system connection list | grep -q rick-dev; then
        echo "Adding new podman system connection with Name \"$remote_alias\"."
        add_connection ssh_id remote_alias remote_ip
    else
        echo "podman system connection already found for Name \"Name\" $remote_alias, skipping connection add."
        echo "To remove the connection, run:"
        echo "    podman system connection remove $remote_alias"
    fi

    local -r secret="k3s-token"
    create_secret secret remote_alias token
}

generate_token() {
    local -n tok="$1"
    # Reference: https://github.com/alexellis/k3sup#create-a-multi-master-ha-setup-with-external-sql
    echo "Generating k3s token now"
    tok="$(openssl rand -base64 64)"
}

add_connection() {
    local -n key="$1"
    local -n host="$2"
    local -n rem_ip="$3"
    # TODO add an option to recreate for an existing entry
    echo "Adding host connection \"$host\" with ip \"$rem_ip\""
    podman system connection add --identity "$key" "$host" "root@${rem_ip}"
    echo "Setting $host as default podman connection"
    podman system connection default "$host"
}

remove_connection() {
    local -n host="$1"

    podman system connection remove "$host"
}

create_secret() {
    local -n sec="$1"
    local -n host="$2"
    local -n tok="$3"

    if podman secret exists "$1"; then
        echo "secret $sec already exists, aborting"
        return 1
    fi

    echo "Creating podman secret \"$sec\" on host \"$host\""
    printf '%s' "$tok" | podman -r -c "$host" secret create "$sec" -
}

main "$@"