#!/bin/bash
# Ansible in a container

ansible() {
    podman run \
            -ti \
            --rm \
            --security-opt label=disable \
            -v ~/.ssh:/root/.ssh \
            -v "$PWD:/apps" \
            -v "$PWD/deploy/ansible/collections/:/usr/share/ansible/collections" \
            -w /apps \
            --env 'ANSIBLE_CONFIG=/apps/deploy/ansible/ansible.cfg' \
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
            -v "$PWD/deploy/ansible/collections/:/usr/share/ansible/collections" \
            -w /apps \
            --env 'ANSIBLE_CONFIG=/apps/deploy/ansible/ansible.cfg' \
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
            -v "$PWD/deploy/ansible/collections/:/usr/share/ansible/collections" \
            -w /apps \
            --env 'ANSIBLE_CONFIG=/apps/deploy/ansible/ansible.cfg' \
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
            -v "$PWD/deploy/ansible/collections/:/usr/share/ansible/collections" \
            -w /apps \
            --env 'ANSIBLE_CONFIG=/apps/deploy/ansible/ansible.cfg' \
            alpine/ansible \
                ansible-galaxy "$@"
}

ansible-config() {
    podman run \
            -ti \
            --rm \
            --security-opt label=disable \
            -v ~/.ssh:/root/.ssh \
            -v "$PWD:/apps" \
            -v "$PWD/deploy/ansible/collections/:/usr/share/ansible/collections" \
            -w /apps \
            --env 'ANSIBLE_CONFIG=/apps/deploy/ansible/ansible.cfg' \
            alpine/ansible \
                ansible-config "$@"
}
