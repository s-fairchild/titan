# Welcome to Project Titan

## What is Titan?

Titan is my home lab project that I use for my locally hosted services. This repository mostly serves as a backup of my code, and an example for others to make use of.

## Getting Started

To create a cluster locally:
```bash
git clone https://github.com/s-fairchild/titan.git
cd titan
k3d cluster create -c /home/steven/k3d-cluster.yaml

# Work around for kubectl usage
echo '
K3D_CLUSTER=titan
kubectl() {
    podman exec -it "$K3D_CLUSTER" kubectl "${@}"
}
' >> ~/.bashrc

source ~/.bashrc
K3D_CLUSTER="Override name if desired"

kubectl cluster-info
```

## Design

All persistant volumes that require storage a retention policy make use of a folder mounted to each agent node `/pvs`.
This is a podman volume mounting the host's `/var/local/k3d/persistentVolumes` to the `/pvs` within the agent nodes.

Current working deployments
- Jellyfin
  - Works with hardware acceleration
  - Currently only one replicaset works due to sqlite database locking

## Goals

Workloads
1. [Pihole](https://github.com/pi-hole/pi-hole)
2. Elasticsearch
3. [MotionPlus](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwidw8T34dH_AhVwF1kFHWfjC20QFnoECC4QAQ&url=https%3A%2F%2Fgithub.com%2FMotion-Project%2Fmotionplus&usg=AOvVaw3LnQpoPIybVa1Z11DAVZ9J&opi=89978449)
   1. For video survuelance recording
4. [Docker Swag](https://github.com/linuxserver/docker-swag#migrating-from-the-old-linuxserverletsencrypt-image)

## Design Goals

1. Multi machine environment setup
