#!/bin/bash

main() {
    init_volumes
    init_network "${CLUSTER_NETWORK}"
    init_secrets
    set_limits
    update_start_firewalld
    enable_podman_socket
    start_cluster
}

configure_tuned() {
    log "Enabling tuned"
    systemctl enable --now tuned

    log "Setting tuned profile to network-latency"
    tuned-adm profile network-latency
    log "$(tuned-adm active)"
}

enable_podman_socket() {
    systemctl enable --now podman.socket
}

start_cluster() {
    systemctl enable --now k3s-server-0
    systemctl enable --now k3s-agent-0
    systemctl enable --now k3s-serverlb
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

update_start_firewalld() {
    log "Enabling all firewalld logging"
    firewall-cmd --set-log-denied=all
    log "Adding firewall rules"
    firewall-cmd --permanent --add-service=kube-apiserver
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-port=10250/tcp # Kublet metrics required for all nodes
    firewall-cmd --permanent --add-port=51820/udp # Flannel wireguard ipv4
    log "Reloading firewalld"
    firewall-cmd --reload

    systemctl enable --now firewalld
    systemctl daemon-reload
}

set_limits() {
    log "Setting sysctl limits"
    # Required for jellyfin filesystem watcher
    sysctl -w fs.inotify.max_user_instances=30000
    sysctl -w fs.inotify.max_user_watches=30000

    sysctl_conf="/etc/sysctl.d/99-sysctl.conf"
    log "Writing sysctl limits to $sysctl_conf"
    echo 'fs.inotify.max_user_watches = 30000
    fs.inotify.max_user_instances = 30000
    ' >> $sysctl_conf
}

# Pre create volumes to apply labels
# volumes that don't exist on the first pod run are created with no options
init_volumes() {
    dirs=(
        /var/lib/k3s/server-0/containers
        /var/local/etc/k3s/manifests
        /var/local/var/k3s/persistentVolumes
	    /var/local/lib/k3s/storage
    )

    # shellcheck disable=SC2068
    for d in ${dirs[@]}; do
        mkdir -p "${d}"
    done

    # k3s-server-0 fails to start container unless all mounts exist
    # create empty kubeconfig
    touch .kube/config

    podman volume create \
                    -l app=k3s-data \
                    -l node=server-0 \
                    -l data=app \
                    compute
}

# dns is disabled to allow coredns to make use of the node's /etc/resolv.conf file
init_network() {
    cluster_network="${1:-k3s}"

    podman network create \
                    --subnet 10.98.0.0/16 \
                    --gateway 10.98.0.254 \
                    --disable-dns \
                    --interface-name=nodes \
                    --label=cluster="${cluster_network}" \
                    nodes

    podman network create \
                    --subnet=10.43.0.0/16 \
                    --gateway=10.43.254.254 \
                    --interface-name=services \
                    --disable-dns \
                    --label=app=k3s \
                    --label=cluster="${cluster_network}" \
                    services

    podman network create \
                    --subnet=10.42.0.0/16 \
                    --gateway=10.42.0.254 \
                    --interface-name=pods \
                    --disable-dns \
                    --label=app=k3s \
                    --label=cluster="${cluster_network}" \
                    pods
}

install_pkgs() {
    pkgs=(
        cri-tools
        vim
        kubernetes-client
        htop
        tuned
    )
    log "Installing packages: ${pkgs[*]}"
    dnf in -y "${pkgs[@]}"
    
    log "Creating oc symbolic link to kubectl"
    ln -s "$(which kubectl)" /usr/local/bin/oc
}

init_secrets() {
    if podman secret exists k3s-token; then
        podman secret rm k3s-token
    fi

    podman secret create -l app=k3s k3s-token --env K3S_TOKEN
}

main
