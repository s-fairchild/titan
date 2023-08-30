#!/bin/bash

mkdir -p /var/local/etc/k3d/manifests
mkdir -p /var/local/var/k3d/persistentVolumes

systemctl enable --now firewalld

firewall-cmd --permanent --add-service=kube-apiserver
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=http
firewall-cmd --reload

# Required for jellyfin filesystem watcher
sysctl -w fs.inotify.max_user_instances=5000
