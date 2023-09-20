#!/bin/bash

# For an unknown reason k3d does not allow labeling worker nodes upon cluster creation
kubectl label node k3d-beth-agent-0 node-role.kubernetes.io/worker=worker

if [[ ! -L /var/run/docker.sock ]]; then
    # Arch Linux podman socket location
    if [[ -f /var/run/podman/podman.sock ]]; then
        ln -s /var/run/podman/podman.sock /var/run/docker.sock
    # Fedora's podman socket location
    elif [[ -f /run/podman/podman.sock ]]; then
        ln -s /run/podman/podman.sock /var/run/docker.sock
    fi
fi
