#!/bin/bash
# Copy k3s files to remote server

set -o nounset

main() {
    host="${1:-all}"
    if [[ $host = "rick" ]]; then
        connection_string="root@rick"
        cp_to_rick
        cp_manifests
    elif [[ $host = "expresso" ]]; then
        connection_string="root@expresso"
        cp_to_expresso
    elif [[ $host = "all" ]]; then
        cp_to_all
    elif [[ $host = "manifests" ]]; then
        connection_string="root@rick"
        cp_manifests
    else
        echo "Usage: ${0} < rick | expresso | all >"
    fi
}

copy_files() {
    local -I connection_string
    scp "${1}" "${connection_string}:${2:-}"
}

cp_to_all() {
    cp_to_rick
    cp_to_expresso
}

cp_to_rick() {
    copy_files k3s_install.env
    copy_files scripts/server_pre_install.sh

    # Apiserver loadbalancer
    copy_files clusterconfig/nginx/nginx.conf /usr/local/etc/k3s/
    copy_files node/k3s-apiserverlb.service /usr/lib/systemd/system/

    # Server
    copy_files node/k3s-server-0.service /usr/lib/systemd/system/
    copy_files node/k3s-server-1.service /usr/lib/systemd/system/
    copy_files node/k3s-server-2.service /usr/lib/systemd/system/
    copy_files node/k3s-server-0.yaml /usr/local/etc/k3s/
    copy_files node/k3s-server-1.yaml /usr/local/etc/k3s/
    copy_files node/k3s-server-2.yaml /usr/local/etc/k3s/
    copy_files node/k3s-applb.yaml /usr/local/etc/k3s/
    copy_files node/k3s-applb.service /usr/lib/systemd/system/
    # Agent
    copy_files node/k3s-agent-0.service /usr/lib/systemd/system/
    copy_files node/k3s-agent-1.service /usr/lib/systemd/system/
    copy_files node/k3s-agent-2.service /usr/lib/systemd/system/
    copy_files node/k3s-agent-0.yaml /usr/local/etc/k3s/
    copy_files node/k3s-agent-1.yaml /usr/local/etc/k3s/
    copy_files node/k3s-agent-2.yaml /usr/local/etc/k3s/
}

cp_manifests() {
    manifests="/var/local/etc/k3s/manifests/"
    skip_files="/var/local/etc/k3s/skip/"

    oc kustomize apps/jellyfin > manifests/jellyfin.yaml 
    copy_files manifests/jellyfin.yaml "$manifests"

    # Traefik helm chart
    copy_files clusterconfig/traefik/traefik-config.yaml "$manifests"
    copy_files clusterconfig/traefik/traefik.yaml.skip "$skip_files"
}

cp_to_expresso() {
    # Agent
    copy_files node/k3s-agent-1.service /usr/lib/systemd/system/
    copy_files node/k3s-agent-1.yaml /usr/local/etc/

    # Loadbalancer
    copy_files node/k3s-expressolb.service /usr/lib/systemd/system/
    copy_files node/k3s-expressolb.yaml /usr/local/etc/
}

main "${@}"
