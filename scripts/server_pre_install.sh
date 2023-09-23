#!/bin/bash

main() {
    init_volumes
    init_network "${CLUSTER_NETWORK}"
    init_secrets
    set_limits
    update_start_firewalld
}

update_start_firewalld() {
    firewall-cmd --permanent --add-service=kube-apiserver
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-port=10250/tcp # Kublet metrics required for all nodes
    firewall-cmd --permanent --add-port=51820/udp # Flannel wireguard ipv4
    firewall-cmd --reload

    systemctl enable --now firewalld
    systemctl daemon-reload
}

set_limits() {
    # Required for jellyfin filesystem watcher
    sysctl -w fs.inotify.max_user_instances=30000
    sysctl -w fs.inotify.max_user_watches=30000

    echo 'fs.inotify.max_user_watches = 30000
    fs.inotify.max_user_instances = 30000
    ' >> /etc/sysctl.d/99-sysctl.conf
}

init_volumes() {
    mkdir -p /var/local/etc/k3s/manifests
    mkdir -p /var/local/var/k3s/persistentVolumes
}

init_network() {
    cluster_network="${1:-k3s}"
    # podman network rm "${cluster_network}"
    podman network create \
                    --ignore \
                    --dns "${CLUSTER_DNS}" \
                    --subnet 10.91.0.0/24 \
                    --interface-name k3s \
                    "${cluster_network}"
    
    # Required to facilitate communication with kubernetes service network
    # kubernetes has a default address of 10.43.0.1, which is why the default gateway is the last address
    podman network create \
                    --ignore \
                    --disable-dns \
                    --gateway 10.43.0.254 \
                    --label app=k3s \
                    --interface-name service \
                    --subnet 10.43.0.0/24 \
                    service
}

install_pkgs() {
    dnf in -y \
            cri-tools
}

init_secrets() {
    if podman secret exists k3s-token; then
        podman secret rm k3s-token
    fi

    podman secret create -l app=k3s k3s-token --env K3S_TOKEN
}

main
