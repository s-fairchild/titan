#!/bin/bash

set -o nounset \
    -o errexit

DEBUG="${DEBUG:-"false"}"
if [ "$DEBUG" == "true" ]; then
    set -x
fi

main() {
    local -r remote_alias="$1"
    local -r ssh_id="$2"

    if [ "$ssh_id" == "remove" ]; then
        remove_connection remote_alias
        exit 0
    fi

    # shellcheck disable=SC2034
    local -r remote_ip="$3"
    # shellcheck disable=SC2034
    local token
    generate_token token

    if ! podman system connection list | grep -q rick-dev; then
        log "Adding new podman system connection with Name \"$remote_alias\"."
        add_connection ssh_id remote_alias remote_ip
    else
        log "podman system connection already found for Name \"Name\" $remote_alias, skipping connection add.
            To remove the connection, run:
                podman system connection remove $remote_alias"
    fi

    # shellcheck disable=SC2034
    local -r secret="k3s-token"
    create_secret secret remote_alias token
}

generate_token() {
    local -n tok="$1"
    # Reference: https://github.com/alexellis/k3sup#create-a-multi-master-ha-setup-with-external-sql
    log "Generating k3s token now"
    tok="$(openssl rand -base64 64)"
}

add_connection() {
    local -n key="$1"
    local -n host="$2"
    local -n rem_ip="$3"
    # TODO add an option to recreate for an existing entry
    log "Adding host connection \"$host\" with ip \"$rem_ip\""
    podman system connection add --identity "$key" "$host" "root@${rem_ip}"
    log "Setting $host as default podman connection"
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

    if podman -r -c "$host" secret exists "$1"; then
        abort "secret $sec already exists, aborting"
    fi

    log "Creating podman secret \"$sec\" on host \"$host\""
    printf '%s' "$tok" | podman -r -c "$host" secret create "$sec" -
}

declare -r utils="hack/lib/util.sh"
if [ -f "$utils" ]; then
    # shellcheck source=lib/util.sh
    source "$utils"
fi

main "$@"