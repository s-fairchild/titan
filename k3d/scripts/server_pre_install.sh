#!/bin/bash

mkdir -p /var/local/k3d/pvs
mkdir -p /usr/local/etc/k3d/man

systemctl enable --now firewalld

firewall-cmd --permanent --add-service=kube-apiserver
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
