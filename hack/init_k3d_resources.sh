#!/bin/bash -x
# Initialize podman resources required to run k3d

set -o nounset \
    -o errexit \
    -o noclobber

trap 'catch' ERR

main() {
    # Establish user defined environment
    local -r user_cluster_env="bootstrap/config/env/bootstrap-cluster-k3d.dev.env"
    local -r default_cluster_env="bootstrap/config/env/bootstrap-cluster-k3d.env"
    local -r k3d_config="bootstrap/config/bootstrap-cluster-k3d.yaml"
    # TODO create registry via config file values
    # local -r k3d_config="bootstrap/config/bootstrap-registry-k3d.yaml"
    if [[ -f  $user_cluster_env ]]; then
        # shellcheck source=../bootstrap/config/env/bootstrap-cluster-k3d.env
        source "$user_cluster_env"
    elif [[ -f $default_cluster_env ]]; then
        # shellcheck source=../bootstrap/config/env/bootstrap-cluster-k3d.env.example
        source "$default_cluster_env"
    fi

    # Establish defaults environment for unset variables
    local DOCKER_HOST="${DOCKER_HOST:-}"
    local DOCKER_SOCK="${DOCKER_SOCK:-"/run/podman/podman.sock"}"
    # TODO use default value subnets
    local CLUSTER_SUBNET_NODES="10.94.0.0/16"
    local CLUSTER_SUBNET_VMS="10.93.0.0/16"
    local CLUSTER_SUBNET_SERVICES="10.46.0.0/16"
    local ROLLBACK=${ROLLBACK:-false}
    local CLUSTER_MANAGER="${CLUSTER_MANAGER:-"bootstrapper"}"
    local CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-"cluster.local"}"
    local TOKEN="${TOKEN:?"TOKEN must be set"}"
    local MANIFESTS="${MANIFESTS:-"k3d-${CLUSTER_MANAGER}-manifests"}"
    local MANIFESTS_SKIP="${MANIFESTS_SKIP:-"k3d-${CLUSTER_MANAGER}-skip-manifests"}"
    local MANAGEMENT_MIRROR_URL="${MANAGEMENT_MIRROR_URL:-"https://registry-1.docker.io"}"
    local MANAGEMENT_REGISTRY_USER="${MANAGEMENT_REGISTRY_USER:-}"
    local MANAGEMENT_REGISTRY_PASS="${MANAGEMENT_REGISTRY_PASS:-}"
    local REGISTRY="${REGISTRY:-"${CLUSTER_MANAGER}-registry.localhost"}"
    local REGISTRY_IMAGE_STORE="${REGISTRY_IMAGE_STORE:-"k3d-registry-images"}"
    local INSTANCE="${INSTANCE:-"$(hostname -s)"}"
    local CLUSTER_NETWORK_NAME_NODES="${CLUSTER_NETWORK_NAME_NODES:-"k3d"}"
    local CLUSTER_APISERVER_ADDVERTISE_IP="10.50.0.202"

    # TODO turn this into a getopts case switch loop
    # TODO add a --debug option for adding `set -T -x`
    # shellcheck disable=SC2068
    if [[ ${#@} -ne 0 ]]; then
        if [[ $1 == "delete-all" ]]; then
            delete_all
        elif [[ $1 == "create-all" ]]; then
            create_all
        elif [[ $1 == "create-volumes" ]]; then
           init_volumes 
        elif [[ $1 == "recreate-all" ]]; then
            delete_all
            create_all
        elif [[ $1 == "get-defaults" ]]; then
            log "Default Environment: "
            local -p
        elif [[ $1 == "help" ]]; then
            usage
        else
            log "${0}: Unkown arg \"${1}\""
            abort usage
        fi
    fi
}

create_all() {
    init_network
    # TODO include a recreate option for this script to optionally delete components
    delete_components "registry"
    init_registry "$REGISTRY" "${CLUSTER_NETWORK_NAME_NODES}"
    create_k3d "${CLUSTER_MANAGER}" "${k3d_config}"
    succeed
}

delete_all() {
    delete_components "all"
    succeed
}

init_registry() {
    local registry="${1}" default_network="${2}"
    k3d registry \
        create \
        "$registry" \
        --default-network="$default_network" \
        --port=0.0.0.0:5000 \
        --no-help \
        --verbose
}

succeed() {
    log "completed successfully"
    return 0
}

usage() {
    echo "${0} < delete-all | create-all | create-volumes>"
}

init_network() {
    local node_net="${CLUSTER_NETWORK_NAME_NODES}"
    podman network create \
                    --ignore \
                    --subnet="${CLUSTER_SUBNET_NODES}" \
                    --interface-name="${CLUSTER_NETWORK_NAME_NODES}-nodes" \
                    --label=name="k3d-nodes" \
                    --label=cluster="${CLUSTER_MANAGER}" \
                    --label=part-of="${CLUSTER_MANAGER}" \
                    --label=instance="${CLUSTER_MANAGER}-${INSTANCE}" \
                    "$node_net"

    local vm_net="k3d-${CLUSTER_MANAGER}-vms"
    podman network create \
                    --ignore \
                    --subnet="${CLUSTER_SUBNET_VMS}" \
                    --interface-name="k3d-vms" \
                    --label=name="${CLUSTER_NETWORK_NAME_NODES}-vms" \
                    --label=cluster="${CLUSTER_MANAGER}" \
                    --label=part-of="$CLUSTER_MANAGER" \
                    --label=instance="${CLUSTER_MANAGER}-${INSTANCE}" \
                    "$vm_net"

    local services_net="k3d-${CLUSTER_MANAGER}-services"
    podman network create \
                    --ignore \
                    --subnet="${CLUSTER_SUBNET_SERVICES}" \
                    --interface-name="${CLUSTER_NETWORK_NAME_NODES}-services" \
                    --label=name="${services_net}" \
                    --label=cluster="${CLUSTER_MANAGER}" \
                    --label=part-of="$CLUSTER_MANAGER" \
                    --label=instance="${CLUSTER_MANAGER}-${INSTANCE}" \
                    "$services_net"

    local pod_net="k3d-${CLUSTER_MANAGER}-pods"
    podman network \
            create \
            --ignore \
            --subnet=10.42.0.0/16 \
            --gateway=10.42.0.254 \
            --interface-name="k3d3" \
            --label=name="${pod_net}" \
            --label=cluster="${CLUSTER_MANAGER}" \
            --label=part-of="${CLUSTER_MANAGER}" \
            --label=instance="${CLUSTER_MANAGER}-${INSTANCE}" \
            --label=cluster="${CLUSTER_MANAGER}" \
            "$pod_net"
}

init_volumes() {
    init_workloads="${1:-false}"
    init_or_recreate_volume "${MANIFESTS}"
    init_or_recreate_volume "${MANIFESTS_SKIP}"
    init_or_recreate_volume "${REGISTRY_IMAGE_STORE}" "${REGISTRY}"

    if [[ $init_workloads == true ]]; then
        init_volume_load_data "${volume_name}" "cluster"
        init_volume_load_data "${volume_name}" "workloads"
    fi
}

init_or_recreate_volume() {
    local volume_name="${1}"
    local label_name="${2:-${1}}"
    log "deleting volume ${volume_name}"
    rm_volume "${volume_name}"

    log "creating volume ${volume_name}"
    podman volume \
            create \
            --label=name="${label_name}" \
            --label=cluster="${CLUSTER_MANAGER}" \
            --label=part-of="${CLUSTER_MANAGER}" \
            --label=instance="${CLUSTER_MANAGER}-${INSTANCE}" \
            --label=cluster="${CLUSTER_MANAGER}" \
            "${volume_name}"
    log "successfully created volume ${volume_name}"
}

init_volume_load_data() {
    local vol="${1}"
    local opt="${2}"

    generate_manifests
    local -a manifests
    if [[ $opt == "cluster" ]]; then
        manifests=(
            coredns
            nginx
            traefik
        )
        pushd ./clusterconfig
    elif [[ $opt == "workloads" ]]; then
        manifests=(
            jellyfin
            motion
            pihole
            v4l2rtspserver
        )
        pushd ./apps
    else
        abort "$opt unknown"
    fi

    local -a manifests=("$(generate_manifests "${manifests[@]}")")

    podman volume exists "${vol}" || abort "${vol} not found"

    # TODO get server-0 k3d name and cp files into volume
    # shellcheck disable=SC2068
    tar c ${manifests[@]} | podman volume cp - "${vol}"

    popd
}

generate_manifests() {
    local -a kdirs=("${@}")
    if [[ ${#kdirs{@}} -eq 0 ]]; then
        abort "input manifests cannot be empty, provided input \${@} length is zero."
    fi
    tmp="$(mktemp -d)"

    local -a manifests
    # shellcheck disable=SC2068
    for k in ${kdirs[@]}; do
        l="${tmp}/${k}.yaml"
        oc kustomize \
            "$k" \
            -o="$l"
        manifests+=("$l")
    done

    echo "${manifests[@]}"
}

podman() {
    command podman -r "${@}"
}

rm_volume() {
    local vol="${1}"
    if podman volume exists "${vol}"; then
        podman volume rm "${vol}"
    fi
}

catch() {
    local -i return_code
    return_code=$1

    # Search for known exit codes
    # shellcheck disable=SC2068
    for c in ${safe_return_codes[@]}; do
        if [[ $c -eq $return_code ]]; then
            echo "${c}"
            return 0
        fi
    done

    abort "Something went wrong, ${return_code} was not found in \$safe_return_codes[@] ${safe_return_codes[*]}"
}

delete_components() {
    local component="${1}"
    local want_cluster="${CLUSTER_MANAGER}"
    local want_registry="k3d-${REGISTRY}"

    if [[ $component == "registry" ]]; then
        delete_registry
    elif [[ $component == "cluster" ]]; then
        delete_cluster
    elif [[ $component == "all" ]]; then
        delete_cluster
        delete_registry
    else
        abort "unknown option $component"
    fi
}

delete_cluster() {
    local cluster_found
    cluster_found=$(k3d cluster list -o=json | jq -r '.[].name')
    if [ "$want_cluster" == "${cluster_found}" ]; then
        k3d \
            cluster \
            delete \
            "${cluster_found}"
    fi
}

delete_registry() {
    local registry_found
    registry_found=$(k3d registry list -o=json | jq -r '.[].name')
    if [ "$want_registry" == "$registry_found" ]; then
        k3d \
            registry \
            delete \
            "${registry_found}"
    fi
}

create_k3d() {
    local cluster="$1" config="$2"
    k3d \
        cluster \
        create \
        --verbose \
        --config="$config" \
        "$cluster"
}

log() {
    local msg="${1:?Log message cannot be unset}"
    local stack_level="${2:-1}"
    echo "${FUNCNAME[${stack_level}]}: ${msg}"
}

abort() {
    log "${1}" "2"
    exit 1
}

main "${@}"
