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
    if [[ -f $user_cluster_env ]]; then
        # shellcheck source=../bootstrap/config/env/bootstrap-cluster-k3d.dev.env
        source "$user_cluster_env"
    elif [[ -f  $user_cluster_env ]]; then
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
    local -rl CLUSTER_MANAGER_NAME="${CLUSTER_MANAGER_NAME:-"cluster-manager"}"
    local -rl CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-"cluster.local"}"
    local -rl MANIFESTS_SKIP="${MANIFESTS_SKIP:-"k3d-${CLUSTER_MANAGER_NAME}-skip-manifests"}"
    local -r MANAGEMENT_MIRROR_URL="${MANAGEMENT_MIRROR_URL:-"https://registry-1.docker.io"}"
    local -r MANAGEMENT_REGISTRY_USER="${MANAGEMENT_REGISTRY_USER:-}"
    local -r MANAGEMENT_REGISTRY_PASS="${MANAGEMENT_REGISTRY_PASS:-}"
    local -rl REGISTRY="${REGISTRY:-"${CLUSTER_MANAGER_NAME}-registry.localhost"}"
    local -rl REGISTRY_IMAGE_STORE="${REGISTRY_IMAGE_STORE:-"k3d-registry-images"}"
    local -r INSTANCE="${INSTANCE:-"$(hostname -s)"}"
    local -r CLUSTER_APISERVER_ADDVERTISE_IP="10.50.0.202"
    local -r OPTION_COPY_MANIFESTS="${OPTION_COPY_MANIFESTS:-false}"
    local -rl node_server_0="k3d-${CLUSTER_MANAGER_NAME}-server-0"
    # Volumes

    # Logging options
    local debug="${DEBUG:-false}"
    # TODO save this token as a podman secret
    local -r TOKEN="${TOKEN:?"TOKEN must be set"}"
    # Constants
    local -r token_podman_secret_name="k3d-${CLUSTER_MANAGER_NAME}-token"
    local -r MANIFESTS="${MANIFESTS:-"k3d-${CLUSTER_MANAGER_NAME}-manifests"}"
    local -r kubevirt_network_name="k3d-${CLUSTER_MANAGER_NAME}-vms"
    local -rl cluster_network_name_nodes="${CLUSTER_NETWORK_NAME_NODES:-"k3d"}"
    local -ra enabled_volumes=(
        VOLUME_MANIFESTS
        VOLUME_MANIFESTS_SKIP
    )

    if [[ ${REMOTE_INSTALL} == "true" ]]; then
        podman() {
            command podman -r ${@}
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
        create_all \
            cluster_network_name_nodes \
            kubevirt_network_name \
            enabled_volumes \
            CLUSTER_MANAGER_NAME
        ;;
    "delete-all")
        delete_all CLUSTER_MANAGER_NAME REGISTRY 
        ;;
    "recreate-all")
        delete_all
        create_all node_server_0 OPTION_COPY_MANIFESTS kubevirt_network_name enabled_volumes
        ;;
    "create-volumes")
        manage_volumes "create" enabled_volumes
        ;;
    "registry-create")
        manage_registry  "create" REGISTRY CLUSTER_NETWORK_NAME_NODES
        ;;
    "registry-delete")
        manage_registry "delete" REGISTRY
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
    "help")
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
    local -n volumes="$2"

    if [[ $action == "create" ]]; then
        init_volumes volumes
    elif [[ $action == "delete" ]]; then
        delete_volumes volumes
    fi
}

delete_volumes() {
    local -n vols="$1"

    # shellcheck disable=SC2068
    for v in ${vols[@]}; do
        rm_volume "$v"
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
            --label=cluster="${CLUSTER_MANAGER_NAME}" \
            --label=part-of="${CLUSTER_MANAGER_NAME}" \
            --label=instance="${CLUSTER_MANAGER_NAME}-${INSTANCE}" \
            --label=cluster="${CLUSTER_MANAGER_NAME}" \
            "${volume_name}"
    log "successfully created volume ${volume_name}"
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

init_volumes() {
    for v in ${@}; do
        recreate_volumes "$v" "$v"
    done
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

# TODO clean this up by passing in an options associative array
# create_all
# arguments: 2
# 1) node to copy files to - string
# 2) enable copy manifests - boolean
# 3) kubevirt network name - string
# 4) Name of cluster to create
# 5) cluster_name k3d cluster name to be created
# 6) cluster_config k3d yaml configuration file location
# 7) Optional: enabled_volumes containing the name of all volumes to be created - string array
create_all() {
    local -n node_network="$1"
    local -n kubevirt_net="$2"
    local -n cluster_name="$3"
    local -n cluster_config="$4"
    local -n enabled_volumes="${5:-NULL}"

    init_network node_network \
                 kubevirt_net

    manage_volumes "create" \
                    enabled_volumes

    manage_registry "create" \
                    REGISTRY \
                    CLUSTER_NETWORK_NAME_NODES

    create_k3d cluster_name \
                cluster_config

    succeed
}

delete_all() {
    local -n cluster="$1"
    local -n registry="$2"
    # local delete_volumes=(
    #     "$3"
    #     "$4"
    # )
    # delete_components "all" cluster registry delete_volumes
    delete_components "cluster" cluster registry
    delete_components "registry" cluster registry ""
    succeed
}

# arguments: 3
# 1) option - Can be: [ "create" | "delete" | "re-create" ]
# 2) registry name - string
# 3) Optional: default podman network - string
#    Note: Required for "create" option 1)
manage_registry() {
    local opt="$1"
    local -n registry="$2"
    local -n default_network="${3:-NULL}"

    if [[ $opt == "create" ]] && [[ -z $default_network ]]; then
        log "Default network must be provided with the option create"
        return 1
    fi

    case "$opt" in
    "create")
        log "Creating registry \"${registry}\" with default network ${default_network}"
        registry_create registry default_network
        ;;
    "delete")
        log "Deleting registry \"${registry}\""
        delete_registry registry
        ;;
    "re-create")
        log "Deleting registry \"${registry}\", then creating registry \"${registry}\" with default network \"${default_network}\""
        delete_registry registry
        ;;
    esac
}

delete_registry() {
    local -n r=$1
    if ! verify_component "registry" "$1"; then
        log "registry \"$r\" not found"
        return 1
    fi


    if ! k3d registry delete $r; then
        log "Delete Registry Failed"
        return 1
    fi
}

registry_create() {
    local -n r="$1"
    local -n def_net="$2"
    if verify_component "registry" "$1"; then
        return 1
    elif ! verify_component "network" "$2"; then
        return 0
    fi

    k3d registry \
        create \
        "$r" \
        --default-network="$def_net" \
        --port="$CLUSTER_REGISTRY_EXTERNAL_IP:$CLUSTER_REGISTRY_EXTERNAL_PORT" \
        --no-help \
        --verbose
    
    if [[ $? -ne 0 ]]; then
        log "failed to create registry \"$r\" with default network \"$def_net\""
        return 1
    fi
}

succeed() {
    log "completed successfully"
    return 0
}

usage() {
    echo "${0} < delete-all | create-all | create-volumes | recreate-all | copy-manifests | token-update-new> | registry-delete | registry-create "
}

init_network() {
    local -n node_net="$1"
    local -n kubevt_net="$2"
    podman network create \
                    --subnet="${CLUSTER_SUBNET_NODES}" \
                    --interface-name="k3d0" \
                    --label=name="$node_net" \
                    --label=cluster="${CLUSTER_MANAGER_NAME}" \
                    --label=part-of="${CLUSTER_MANAGER_NAME}" \
                    --label=instance="${CLUSTER_MANAGER_NAME}-${INSTANCE}" \
                    "$node_net"

    podman network create \
                    --subnet="${CLUSTER_SUBNET_VMS}" \
                    --interface-name="k3d1" \
                    --label=name="$kubevt_net" \
                    --label=cluster="$CLUSTER_MANAGER_NAME" \
                    --label=part-of="$CLUSTER_MANAGER_NAME" \
                    --label=instance="${CLUSTER_MANAGER_NAME}-${INSTANCE}" \
                    "$kubevt_net"

    local services_net="k3d-${CLUSTER_MANAGER_NAME}-services"
    podman network create \
                    --subnet="${CLUSTER_SUBNET_SERVICES}" \
                    --interface-name="k3d2" \
                    --label=name="${services_net}" \
                    --label=cluster="${CLUSTER_MANAGER_NAME}" \
                    --label=part-of="$CLUSTER_MANAGER_NAME" \
                    --label=instance="${CLUSTER_MANAGER_NAME}-${INSTANCE}" \
                    "$services_net"

    local pod_net="k3d-${CLUSTER_MANAGER_NAME}-pods"
    podman network \
            create \
            --subnet="${CLUSTER_SUBNET_PODS}" \
            --interface-name="k3d3" \
            --label=name="${pod_net}" \
            --label=cluster="${CLUSTER_MANAGER_NAME}" \
            --label=part-of="${CLUSTER_MANAGER_NAME}" \
            --label=instance="${CLUSTER_MANAGER_NAME}-${INSTANCE}" \
            --label=cluster="${CLUSTER_MANAGER_NAME}" \
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

    abort "Something went wrong: ${return_code}"
}

delete_components() {
    local component="$1"
    local -n want_cluster="$2"
    local -n want_registry="$3"
    local -n volumes="$4"

    if [[ $component == "registry" ]]; then
        # log "Starting component deletion \"$component\""
        manage_registry "delete" registry
    elif [[ $component == "cluster" ]]; then
        # log "Starting component deletion \"$component\""
        delete_cluster want_cluster
    elif [[ $component == "all" ]]; then
        delete_cluster want_cluster
        manage_registry "delete" registry
        delete_volumes volumes
    else
        log "unknown component: ${component}"
        return 1
    fi

    return 0
}

delete_cluster() {
    local -n c="$1"
    if ! verify_component "cluster" "$1"; then
        log "failed to find cluster \"$c\""
        return 1
    fi

    if ! k3d cluster delete "$c"; then
        log "failed to delete cluster \"$c\""
        return 1
    fi
}

verify_component() {
    local type="$1"
    local -n want="$2"
    if [[ $type == "cluster" ]]; then
        if ! k3d cluster list "$want" > /dev/null; then
            return 1
        fi
    elif [[ $type == "registry" ]]; then
        if ! k3d registry list "$want" > /dev/null; then
            return 1
        fi
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

# NULL variable to use for optional name reference arguements inside functions
# In other words, it's a pointer and can't be assigned a value as a default option
# but rather the referencing variable
declare -r NULL=""

option="$1"
main option
