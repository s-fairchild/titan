#!/bin/bash
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
    local CLUSTER_SUBNET_NODES="${CLUSTER_SUBNET_NODES:-10.94.0.0/16}"
    local CLUSTER_SUBNET_VMS="${CLUSTER_SUBNET_VMS:-10.93.0.0/16}"
    local CLUSTER_SUBNET_SERVICES="${CLUSTER_SUBNET_SERVICES:-10.46.0.0/16}"
    local ROLLBACK=${ROLLBACK:-false}
    # TODO allow overriding vars set in .env with cmd line arg for cluster name
    local -rl CLUSTER_MANAGER="${CLUSTER_MANAGER:-"cluster-manager"}"
    local -rl CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-"cluster.local"}"
    local -rl MANIFESTS_SKIP="${MANIFESTS_SKIP:-"k3d-${CLUSTER_MANAGER}-skip-manifests"}"
    local -r MANAGEMENT_MIRROR_URL="${MANAGEMENT_MIRROR_URL:-"https://registry-1.docker.io"}"
    local -r MANAGEMENT_REGISTRY_USER="${MANAGEMENT_REGISTRY_USER:-}"
    local -r MANAGEMENT_REGISTRY_PASS="${MANAGEMENT_REGISTRY_PASS:-}"
    local -rl REGISTRY="${REGISTRY:-"${CLUSTER_MANAGER}-registry.localhost"}"
    local -rl REGISTRY_IMAGE_STORE="${REGISTRY_IMAGE_STORE:-"k3d-registry-images"}"
    local -r INSTANCE="${INSTANCE:-"$(hostname -s)"}"
    local -rl CLUSTER_NETWORK_NAME_NODES="${CLUSTER_NETWORK_NAME_NODES:-"k3d"}"
    local -r CLUSTER_APISERVER_ADDVERTISE_IP="10.50.0.202"
    local -r OPTION_COPY_MANIFESTS="${OPTION_COPY_MANIFESTS:-false}"
    local -rl node_server_0="k3d-${CLUSTER_MANAGER}-server-0"
    # Logging options
    local debug="${DEBUG:-false}"
    # TODO save this token as a podman secret
    local -r TOKEN="${TOKEN:?"TOKEN must be set"}"
    # Constants
    local -r token_podman_secret_name="k3d-${CLUSTER_MANAGER}-token"
    local -r MANIFESTS="${MANIFESTS:-"k3d-${CLUSTER_MANAGER}-manifests"}"

    if [[ ${REMOTE_INSTALL} == "true" ]]; then
        podman() {
            command podman -r "${@}"
        }
    fi

    if [[ "$debug" == true ]]; then
        set -x
    fi

    local -n arg1="${1:-help}"
    # TODO turn this into a getopts case switch loop
    # TODO add a --debug option for adding `set -T -x`
    case $arg1 in
    "create-all")
        create_all node_server_0 OPTION_COPY_MANIFESTS
        ;;
    "delete-all")
        delete_all
        ;;
    "recreate-all")
        delete_all
        create_all node_server_0 OPTION_COPY_MANIFESTS
        ;;
    "create-volumes")
        manage_volumes "create"
        ;;
    "copy-manifests")
        exit_not_implimented
        ;;
    "token-update-new")
        save_secret token_podman_secret_name TOKEN
        ;;
    "get-defaults")
        log "Default Environment: "
        local -p
        ;;
    "help")token=TOKEN
        ;;
    *)
        log "${0}: Unkown arg \"${1}\""
        usage
        abort
        ;;
    esac
}

exit_not_implimented() {
    log "\"$arg1\" is not currently implimented. "
    return 0
}

manage_volumes() {
    local action="$1"
    local -a volumes=(
        "${VOLUME_MANIFESTS}"
        "${VOLUME_MANIFESTS_SKIP}"
    )

    if [[ $action == "create" ]]; then
        init_volumes "${volumes[@]}"
    elif [[ $action == "delete" ]]; then
        delete_volumes "${volumes[@]}"
    fi
}

error_log_check() {
    local f="$1"
    if [[ ! -f $f ]]; then
        log "\"$f\" error log not found"
        return 1
    fi
    c=$(wc -c "$f")
    if [[ ${c:0:1} -ne 0 ]]; then
        log "$f: \n$(cat "$f")"
        return 1
    fi
}

delete_volumes() {
    local -a volumes=("${@}")

    # shellcheck disable=SC2068
    for v in ${volumes[@]}; do
        rm_volume "$v"
    done
}

init_volumes() {
    local -a volumes=("${@}")

    # shellcheck disable=SC2068
    for v in ${volumes[@]}; do
        recreate_volumes "$v" "$v"
    done
}

recreate_volumes() {
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

# save_token
# arguments: 2
# 1) podman secret name
# 2) podman secret value
save_secret() {
    local -n secret_name="$1"

    if podman secret exists "$secret_name"; then
        log "secret \"$secret_name\" already exists, skipping
        to regenerate \"$secret_name\", run: \"podman secret delete $secret_name\""
    else
        podman secret create "$secret_name" --env "$2"
    fi
}

create_all() {
    local -n node_copy_to="$1"
    local -n opt_cp_manifests="$2"
    init_network
    manage_volumes "create"
    # TODO include a recreate option for this script to optionally delete components
    manage_registry "$REGISTRY" "${CLUSTER_NETWORK_NAME_NODES}" "create"
    create_k3d "${CLUSTER_MANAGER}" "${k3d_config}"

    if [[ $opt_cp_manifests == true ]]; then
        copy_all_to_node "$node_copy_to"
    else
        log "Skipping node copy"
    fi

    succeed
}

delete_all() {
    delete_components "all"
    succeed
}

manage_registry() {
    local registry="${1}"
    local default_network="${2}"
    local opt="${3}"

    case "$opt" in

    "create")
        log "Creating registry ${registry} with default network ${default_network}"
        ;;
    "delete")
        log "Deleting registry ${registry}"
        ;;
    "re-create")
        log "Deleting registry ${registry}, then creating registry ${registry} with default network ${default_network}"
        delete_registry "${registry}"
        ;;
    esac

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
    echo "${0} < delete-all | create-all | create-volumes | recreate-all | copy-manifests | token-update-new>"
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

rm_volume() {
    local node="${1}"
    if podman volume exists "${node}"; then
        podman volume rm "${node}"
    fi
}

catch() {
    local -i return_code
    return_code=$1

    # Search for known exit codes
    # shellcheck disable=SC2068
    # for c in ${safe_return_codes[@]}; do
    #     if [[ $c -eq $return_code ]]; then
    #         echo "${c}"
    #         return 0
    #     fi
    # done

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
        delete_volumes "${volumes[@]}"
    else
        abort "unknown component: ${component}"
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
    # TODO cleanup references to delete_registry, ensuring they all pass in the desired registry name, rather than using the inhereted $want_registry
    # remove default value after this
    local registry="${1:-$want_registry}"
    local registry_found
    registry_found=$(k3d registry list -o=json 2> /dev/null | jq -r '.[].name')
    if [ "$registry" == "$registry_found" ]; then
        k3d \
            registry \
            delete \
            "${registry_found}"
    fi
}

create_k3d() {
    local cluster="${1:?Cluster name must be provided}"
    local config="${2:?Cluster config location must be provided}"
    k3d \
        cluster \
        create \
        --verbose \
        --config="$config" \
        "$cluster"
}

# log
# arguments: 2
# 1) error message to log
# 2) optional: custom stack level, changes the function stack level the message is logged from
#    defaults to one function above itself
log() {
    local msg="${1:?Log message cannot be unset}"
    local stack_level="${2:-1}"
    echo "${FUNCNAME[${stack_level}]}: ${msg}"
}

# abort
# arguments: 2
# 1) error message to log
# 2) optional: custom stack level, changes the function stack level the message is logged from
#    defaults to 2 above itself
abort() {
    log "${1:-"aborting..."}" "${2:-2}"
    exit 1
}

option="$1"
main option
