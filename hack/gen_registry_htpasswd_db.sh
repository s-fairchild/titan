#!/bin/bash
# Generates a htpasswd database with a single user, then stores it within a podman secret

set -o nounset \
    -o errexit

main() {
    local -r registry_user="$1"
    local -r registry_password="$2"

    local secret_file
    generate_htpasswd_db "$registry_user" \
                            "$registry_password" \
                            secret_file

    # shellcheck disable=SC2034
    local -r secret_file
    create_secret secret_file "registry-auth"
}

generate_htpasswd_db() {
    user="$1"
    password="$2"
    local -n out="$3"
    log "starting"

    log "Creating htpasswd database in memory now"
    # shellcheck disable=SC2034
    out="$(htpasswd -bBn "${user}" "${password}")"
}

create_secret() {
    local -n secret="$1"
    local secret_name="$2"
    log "starting"
    log "Attempting to create podman secret $secret_name now"
    # TODO add a prompt to continue or exit here
    log "WARNING: any existing secret named $secret_name will be replaced"

    if podman secret create --replace "$secret_name" - <<< "$secret"; then
        log "Successfully created podman secret $secret_name"
    fi
}

declare -r utils="hack/utils.sh"
if [ -f "$utils" ]; then
    # shellcheck source=utils.sh
    source "$utils"
fi

main "$@"
