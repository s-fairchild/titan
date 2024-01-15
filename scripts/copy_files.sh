#!/bin/bash
# Copy k3s files to remote server

set -o nounset

main() {
    host="${1:-all}"
    if [[ $host = "systemd" ]]; then
        connection_string="root@rick"
        cp_systemd
        cp_configs "/usr/local/etc/k3s/"
    elif [[ $host = "expresso" ]]; then
        connection_string="root@expresso"
        cp_to_expresso
    elif [[ $host = "all" ]]; then
        echo "Not implimented yet."
        # cp_to_all
    elif [[ $host = "manifests" ]]; then
        connection_string="root@rick"
        cp_manifests
    elif [[ $host = "configs" ]]; then
        connection_string="root@rick"
        cp_configs "/usr/local/etc/k3s/"
    else
        echo "Usage: ${0} < configs | systemd | manifests | all >"
    fi
}

copy_files() {
    local -I connection_string
    scp "${1}" "${connection_string}:${2:-}"
}

cp_to_all() {
    cp_systemd
    cp_configs
}

cp_systemd() {
    copy_files scripts/server_pre_install.sh
    # Apiserver loadbalancer
    copy_files node/k3s-apiserverlb.service /usr/lib/systemd/system/

    # Server
    copy_files node/k3s-server-0.service /usr/lib/systemd/system/
    copy_files node/k3s-server-1.service /usr/lib/systemd/system/
    copy_files node/k3s-server-2.service /usr/lib/systemd/system/
    copy_files node/k3s-applb.service /usr/lib/systemd/system/
    # Agent
    copy_files node/k3s-agent-0.service /usr/lib/systemd/system/
    copy_files node/k3s-agent-1.service /usr/lib/systemd/system/
    copy_files node/k3s-agent-2.service /usr/lib/systemd/system/
}

cp_configs() {
    # Server
    etc="${1}"
    copy_files node/k3s-server-0.yaml "$etc"
    copy_files node/k3s-server-1.yaml "$etc"
    copy_files node/k3s-server-2.yaml "$etc"
    copy_files node/k3s-applb.yaml "$etc"
    # Agent
    copy_files node/k3s-agent-0.yaml "$etc"
    copy_files node/k3s-agent-1.yaml "$etc"
    copy_files node/k3s-agent-2.yaml "$etc"
    # Apiserver loadbalancer
    copy_files clusterconfig/nginx/nginx.conf /usr/local/etc/k3s/
}

cp_manifests() {
    manifests="/var/local/etc/k3s/manifests/"
    # skip_files="/var/local/etc/k3s/skip/"

    oc kustomize apps/jellyfin > manifests/jellyfin.yaml 
    copy_files manifests/jellyfin.yaml "$manifests"

    # Traefik helm chart
    copy_files clusterconfig/traefik/traefik-config.yaml "$manifests"

    copy_files clusterconfig/coredns/coredns-custom-cm.yaml "$manifests"

    copy_files manifests/metallb.yaml "$manifests"
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
