#!/bin/bash
# Used to create podman networks upon first boot of Fedora CoreOS server needed for k3s

set -o nounset \
    -o errexit

if [ "${DEBUG:-false}" == true ]; then
    set -x
fi

main() {
    local -r stamp="${1:-$0}.stamp"
    # File stamp to create upon successful completion
    local -r stamp_loc="/var/lib/$stamp"

    # shellcheck disable=SC2034
    # Used for network labels
    # TODO place this in an environment file used by the systemd unit
    local -r cluster="rick"

    # TODO place these in an environment file used by the systemd unit
    local -r node_subnet="10.98.0.0/16"
    local -r pod_subnet="10.42.0.0/16"
    local -r service_subnet="10.43.0.0/16"

    # shellcheck disable=SC2034
    # Key is network name, value is subnet
    local -rA init_networks=(
        # TODO create server and agent networks
        [node]="$node_subnet"
        [pod]="$pod_subnet"
        [service]="$service_subnet"
    )

    # TODO place these in an environment file used by the systemd unit
    declare -r node_gateway="10.98.0.254"
    declare -r pod_gateway="10.42.0.254"
    declare -r service_gateway="10.43.254.254"

    # shellcheck disable=SC2034
    # Key is name of the network, value is it's default gateway
    local -rA default_gateways=(
        [node]="$node_gateway"
        [pod]="$pod_gateway"
        [service]="$service_gateway"
    )

    if create_networks cluster \
                       init_networks \
                       default_gateways; then
        touch "$stamp_loc"
    fi
}

create_networks() {
    local -n cluster_name="$1"
    local -n networks="$2"
    local -n gateways="$3"

    # shellcheck disable=SC2068
    for net in ${!networks[@]}; do
        podman network \
                create \
                --subnet="${networks[$net]}" \
                --gateway="${gateways[$net]}" \
                --interface-name="${net}0" \
                --label=cluster="$cluster_name" \
                "$net" && echo "Successfully created podman network $net with gateway ${gateways[$net]}"
    done
}

main "$@"
