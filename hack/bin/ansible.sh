#!/bin/bash
# Ansible in a container

ansible() {
    podman run \
            -ti \
            --rm \
            --security-opt label=disable \
            -v ~/.ssh:/root/.ssh \
            -v "${PWD}":/apps \
            -v ansible-collections:/usr/share/ansible/collections:Z \
            -w /apps \
            alpine/ansible \
                ansible "$@"
}

ansible-playbook() {
    podman run \
            -ti \
            --rm \
            --security-opt label=disable \
            -v ~/.ssh:/root/.ssh \
            -v "${PWD}":/apps \
            -v ansible-collections:/usr/share/ansible/collections:Z \
            -w /apps \
            alpine/ansible \
                ansible-playbook "$@"
}

ansible-inventory() {
    podman run \
            -ti \
            --rm \
            --security-opt label=disable \
            -v ~/.ssh:/root/.ssh \
            -v "${PWD}":/apps \
            -v ansible-collections:/usr/share/ansible/collections:Z \
            -w /apps \
            alpine/ansible \
                ansible-inventory "$@"
}

ansible-galaxy() {
    podman run \
            -ti \
            --rm \
            --security-opt label=disable \
            -v ~/.ssh:/root/.ssh \
            -v "${PWD}":/apps \
            -v ansible-collections:/usr/share/ansible/collections:Z \
            -w /apps \
            alpine/ansible \
                ansible-galaxy "$@"
}
