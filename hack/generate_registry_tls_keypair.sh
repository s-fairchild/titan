#!/bin/bash
# Generate a TLS keypair and self signed certificate for the container registry server
#

set -o nounset \
    errexit

main() {
    generate_tls_keypair
    setup_container_registry "${REGISTRY_USER}" "${REGISTRY_PASSWORD}"
}

setup_container_registry() {
    registry_user="${1}"
    registry_password="${2}"

    registry_root="/var/local/lib/registry"
    pushd "$registry_root" || abort "failed to enter $registry_root. Does it exist?"
    mkdir -p "${registry_root}/{auth,certs,data}"
    htpasswd -bBc \
            ./htpasswd \
            "${registry_user}" \
            "${registry_password}"
}

generate_tls_keypair() {
    log "Creating registry TLS keypair and self signed certificate."
    log "Note: the private key will be unencrypted."
    c="hub"
    cn="${c}.$(hostname --fqdn)"
    st="$(hostname -s)"
    openssl req \
            -newkey rsa:4096 \
            -nodes \
            -sha256 \
            -keyout "./${cn}.key" \
            -x509 \
            -days 365 \
            -out "./${cn}.crt" \
            -subj "/ST=${st}/L=expresso/O=Infra/OU=IT/CN=${cn}"
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

main "${@}"
