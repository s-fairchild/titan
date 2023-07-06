#!/bin/bash
# k3d titan installation script

set -o nounset

main() {
    local config="$1"
    if [[ -f $config ]]; then
        cluster_name="$(grep -s '  name: ' "$1" | cut -d ' ' -f 4)"
        cluster_name="${cluster_name:-}"
        if k3d cluster create -c "$config"; then
            echo "Successfully created cluster $cluster_name"
        else
            echo "failed to create cluster $cluster_name"
        fi
    fi
}

main "$@"
