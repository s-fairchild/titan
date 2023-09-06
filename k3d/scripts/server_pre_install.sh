#!/bin/bash

main() {
    init_volumes
    set_limits
    update_start_firewalld
}

update_start_firewalld() {
    firewall-cmd --permanent --add-service=kube-apiserver
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-forward-port=port=53:proto=tcp:toport=32053:toaddr=10.50.0.2
    firewall-cmd --permanent --add-forward-port=port=53:proto=udp:toport=32053:toaddr=10.50.0.2
    firewall-cmd --reload

    systemctl enable --now firewalld
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
    mkdir -p /var/local/etc/k3d/manifests
    mkdir -p /var/local/var/k3d/persistentVolumes
}
