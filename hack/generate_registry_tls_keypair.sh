#!/bin/bash -x
# Generate a TLS keypair and self signed certificate for the container registry server
#

set -o nounset \
    -o errexit

main() {
    registry_root="/var/local/lib/registry"
    # Certificate info
    c="hub"
    cn="${c}.$(hostname --fqdn)"
    keyout="./${cn}.key"
    crtout="./${cn}.crt"
    # Podman secret info
    secret_prefix="k3s-registry"
    secret_key="$secret_prefix-key"
    secret_crt="$secret_prefix-crt"
    secret_htpasswd="$secret_prefix-htpasswd"
    htpasswd_out=".htpasswd"

    local -A secrets=(
        ["$secret_key"]="$keyout"
        ["$secret_crt"]="$crtout"
        ["$secret_htpasswd"]="$htpasswd_out"
    )

    arg="${1}"

    if [[ $arg == "create-all" ]]; then
        create_all
    elif [[ $arg == "delete-all" ]]; then
        delete_all
    else
        echo "usage: [ create-all | delete-all ]"
    fi

}

delete_all() {
    for s in ${secrets[@]}; do
        local -I secrets
        log "Deleting secrets ${secrets["$s"]}"
        secret="${secrets["$s"]}"
        if podman secret exists; then
            podman secret rm "$secret"
            log "deleted podman secret $secret"
        else
            log "podman secret $secret not found."
        fi
    done
}

create_all() {
    if [[ -d $registry_root ]]; then
        abort "$registry_root root already exists. Please backup and remove before proceeding."
    else
        mkdir -p $registry_root
    fi

    check_secrets_exist
    generate_tls_keypair
    generate_httpd_passwd "${REGISTRY_USER}" "${REGISTRY_PASSWORD}"
}

generate_httpd_passwd() {
    registry_user="${1}"
    registry_password="${2}"

    pushd "$registry_root" || abort "failed to enter $registry_root. Does it exist?"
    mkdir -p "${registry_root}/"{auth,certs,data}

    htpasswd -bBc \
            "${htpasswd_out}" \
            "${registry_user}" \
            "${registry_password}"

}

generate_tls_keypair() {
    tmp="$(mktemp -d)"
    pushd "$tmp" || abort "failed to pushd into $tmp"
    log "Creating registry TLS keypair and self signed certificate."
    log "Note: the private key will be unencrypted."
    st="$(hostname -s)"
    openssl req \
            -newkey rsa:4096 \
            -nodes \
            -sha256 \
            -keyout "${keyout}" \
            -x509 \
            -days 365 \
            -out "${crtout}" \
            -subj "/ST=${st}/L=expresso/O=Infra/OU=IT/CN=${cn}"
}

create_all_secrets() {
    for s in ${secrets[@]}; do
        create_secret "$s" "${secrets["$s"]}"
    done
}

create_secret() {
    secret="${1}"
    secret_file="${2}"
    err_prefix="failed to create ${secret} "
    if [[ ! -f $secret_file ]]; then
        abort "${err_prefix}, $secret_file not found."
    fi
    podman secret create "${secret}" "${secret_file}" || abort "$err_prefix from ${secret_file}"
    log "Successfully created ${secret} from ${secret_file}"
    log "deleting $secret_file now"
    rm -f "${secret_file}" || abort "failed to delete $secret_file"
}

check_secrets_exist() {
    for s in ${secrets[@]}; do
        if podman secret exists "$s"; then
            abort "cannot proceed, $s exists. Backup and delete $s to continue."
        fi
    done
}

log() {
    logger -p "local3.${priority:-info}" -s -i --id=$$ "${FUNCNAME[${stack_level:-1}]}: ${*}"
}

abort() {
    priority="err"
    stack_level=2
    log "${@}"
    exit 1
}

main "${1}"
