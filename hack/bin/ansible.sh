#!/bin/bash
# Ansible in a container

ansible() {
    podman run \
            -ti \
            --rm \
            --security-opt label=disable \
            -v ~/.ssh:/root/.ssh \
            -v "$PWD:/apps" \
            -v "$PWD/.ansible:/usr/share/ansible/collections" \
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
            -v "$PWD:/apps" \
            -v "$PWD/.ansible:/usr/share/ansible/collections" \
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
            -v "$PWD:/apps" \
            -v "$PWD/.ansible:/usr/share/ansible/collections" \
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
            -v "$PWD:/apps" \
            -v "$PWD/.ansible:/root/.ansible" \
            -w /apps \
            alpine/ansible \
                ansible-galaxy "$@"
}
