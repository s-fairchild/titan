#!/bin/bash
# Initialize podman resources required to run k3d

set -o nounset \
    -o errexit \
    -o noclobber \
    -o monitor

trap 'catch' ERR

main() {
    # TODO checkout shellcheck options and see how to get function defentions here
    # TODO turn this into a getopts case switch loop, using the existing options as long options, and = as the seperator for short options
    # TODO add a --debug option for adding `set -T -x`
    case $user_flag_1 in
    "create-all")
        create_all \
            DEFAULT_NETWORK_NAME \
            kubevirt_net_name \
            service_net_name \
            CLUSTER_MANAGER_NAME \
            K3D_CONFIG_FILE \
            "${VOLUMES[@]}" \
            rm_and_create_vols
        ;;
    "delete-all")
        delete_all \
            CLUSTER_MANAGER_NAME \
            REGISTRY 
        ;;
    "recreate-all")
        delete_all \
            CLUSTER_MANAGER_NAME \
            REGISTRY 

        create_all \
            cluster_network_name_nodes \
            kubevirt_network_name \
            CLUSTER_MANAGER_NAME
        ;;
    "volumes-create")
        log "Creating volumes..."
        manage_volumes "create" \
                        "${VOLUMES_ALL[@]}"
                        "$volume_rm_then_create"
        ;;
    "volumes-rm")
        log "Deleting volumes..."
        manage_volumes "rm" \
                        "${VOLUMES_ALL[@]}"
                        "$volume_rm_then_create"
        ;;
    "networks-create")
        manage_networks "create" \
                        DEFAULT_NETWORK_NAME \
                        KUBEVIRT_NETWORK_NAME \
                        SERVICE_NETWORK_NAME \
                        POD_NETWORK_NAME \
                        DEFAULT_NETWORK_SUBNET \
                        KUBEVIRT_NETWORK_SUBNET \
                        SERVICE_NETWORK_SUBNET \
                        POD_NETWORK_SUBNET \
                        CLUSTER_MANAGER_NAME \
                        INSTANCE
    ;;
    "networks-rm")
        manage_networks "rm" \
                        DEFAULT_NETWORK_NAME \
                        KUBEVIRT_NETWORK_NAME \
                        SERVICE_NETWORK_NAME \
                        POD_NETWORK_NAME \
        return $?
        ;;
    "registry-create")
        manage_registry "create" \
                        REGISTRY \
                        CLUSTER_NETWORK_NAME_NODES
        return $?
        ;;
    "registry-delete")
        manage_registry "delete" \
                        REGISTRY
        return $?
        ;;
    "copy-manifests")
        exit_not_implimented "$user_flag_1"
        return $?
        ;;
    "token-update-new")
        save_secret token_podman_secret_name \
                    TOKEN
        return $?
        ;;
    "show-env")
        log "Default Environment: "
        local -p
        return $?
        ;;
    "help")
        usage
        return $?
        ;;
    *)
        log "${0}: Unkown arg \"${user_flag_1}\""
        usage
        abort
        ;;
    esac
}

# init_main
#
# Uses parent environment to initialize main() environment
# Sets defaults for certian values, critical settings
# will cause abort() if unset rather than supplying defaults
# arguments:
# 1) user_flag_1 - nameref;
#      Primary run option
# 2) env_file - nameref;
#      Path to the environment file to source
# 3) k3d_config_file - nameref
#      Path to k3d yaml configuration file
# 4) dev_mode - bool; Defaults to true
#      true: results using the default podman config options
#      false: results in podman --remote being used with default connection
init_main() {
    local -n user_flag_1="${1:-FLAG_HELP}"
    local -n env_file="$2"
    local -n k3d_config_file="$3"
    local dev_mode="$4"

    if [[ ${dev_mode:=true} ]]; then
        log "Development mode is enabled=$dev_mode"
    fi

    if [[ ! -f $env_file ]]; then 
        abort "env_file \"$env_file\" not found"
    fi
    log "Sourcing $env_file"
    # shellcheck source=../bootstrap/config/env/bootstrap-cluster-k3d.dev.env
    source "$env_file"

    if [[ ! -f $k3d_config_file ]]; then
        abort "k3d_config_file \"$k3d_config_file\" not found"
    fi
    log "Using k3d config file: $k3d_config_file"

    # TODO change from default expansion to assignment
    # Establish defaults environment for unset variables
    local -r DOCKER_HOST="${DOCKER_HOST:=}"
    local -r DOCKER_SOCK="${DOCKER_SOCK:="/run/podman/podman.sock"}"
    local -rg ROLLBACK=${ROLLBACK:=false}
    # TODO allow overriding vars set in .env with cmd line arg for cluster name
    local -rl CLUSTER_MANAGER_NAME="${CLUSTER_MANAGER_NAME:="cluster-manager"}"
    local -rl CLUSTER_DOMAIN="${CLUSTER_DOMAIN:="cluster.local"}"
    local -rl MANIFESTS_SKIP="${MANIFESTS_SKIP:="k3d-${CLUSTER_MANAGER_NAME}-skip-manifests"}"
    local -r MANAGEMENT_MIRROR_URL="${MANAGEMENT_MIRROR_URL:="https://registry-1.docker.io"}"
    local -r MANAGEMENT_REGISTRY_USER="${MANAGEMENT_REGISTRY_USER:=""}"
    local -r MANAGEMENT_REGISTRY_PASS="${MANAGEMENT_REGISTRY_PASS:=""}"
    local -rl REGISTRY="${REGISTRY:="${CLUSTER_MANAGER_NAME}-registry.localhost"}"
    local -rl REGISTRY_IMAGE_STORE="${REGISTRY_IMAGE_STORE:="k3d-registry-images"}"
    local -r INSTANCE="${INSTANCE:="$(hostname -s)"}"
    local -r OPTION_COPY_MANIFESTS="${OPTION_COPY_MANIFESTS:=false}"
    local -rl node_server_0="k3d-${CLUSTER_MANAGER_NAME}-server-0"
    # DEBUG log setting
    local debug="${DEBUG:=false}"
    local -r TOKEN="${TOKEN:-}"

    # Networking
    local -r token_podman_secret_name="k3d-${CLUSTER_MANAGER_NAME}-token"
    # Default podman network
    # used by registry and server nodes
    local -r CLUSTER_DEFAULT_NETWORK="${CLUSTER_DEFAULT_NETWORK:="k3d"}"
    local -r DEFAULT_NETWORK_SUBNET="${CLUSTER_SUBNET_NODES:="10.98.0.0/16"}"
    local -r KUBEVIRT_NETWORK_NAME="${CLUSTER_MANAGER_NAME}-kubevirt"
    local -r KUBEVIRT_NETWORK_SUBNET="${CLUSTER_SUBNET_VMS:="10.90.0.0/16"}"
    local -r SERVICE_NETWORK_NAME="${CLUSTER_MANAGER_NAME}-service"
    local -r SERVICE_NETWORK_SUBNET="${CLUSTER_SUBNET_SERVICES:="10.43.0.0/16"}"
    local -r POD_NETWORK_NAME="${CLUSTER_MANAGER_NAME}-pod"
    local -r POD_NETWORK_SUBNET="${POD_NETWORK_SUBNET:="10.42.0.0/16"}"
    local -r CLUSTER_APISERVER_ADDVERTISE_IP="${CLUSTER_APISERVER_ADDVERTISE_IP:?"Cluster apiserver IP not provided"}"

    local -r VOLUME_MANIFESTS="${VOLUME_MANIFESTS:="k3d-${CLUSTER_MANAGER_NAME}-manifests"}"
    local -r VOLUME_SKIP_MANIFESTS="${VOLUME_SKIP_MANIFESTS:="k3d-${CLUSTER_MANAGER_NAME}-skip-manifests"}"
    local -ra VOLUMES=(
            vol_manifests
            vol_skip_manifests
        )
    local -r rm_and_create_vols="$BOOL_FALSE"

    local -a podman_options
    if [[ $debug == true ]]; then
        set -x
        podman_options+=("--log-level=DEBUG")
    fi

    local -rt REMOTE_INSTALL="${REMOTE_INSTALL:-false}"
    if [[ ${REMOTE_INSTALL} == "true" ]]; then
        podman() {
            # shellcheck disable=SC2068
            command podman -r "${podman_options[@]}" ${@}
        }
    fi

    declare -pF main
    main
}

exit_not_implimented() {
    log "\"$1\" is not currently implimented. "
    return 0
}

# manage_volumes
# arguments:
# 1) action - [ create | rm ]; Create or rm a volume
# 2) pending_volumes - space seperated string of namerefs; Gets converted into an array for processing multiple volumes
# 3) rm_existing_volumes - boolean true existing volumes will be deleted
manage_volumes() {
    local -rl action="$1"
    read -a pending_volumes <<< "$2"
    local rm_existing_volumes="$3"

    # ensure podman volume only gets create or rm
    if [[ $action != "create" ]] && [[ $action != "rm" ]]; then
        return 1
    fi

    for v in ${pending_volumes[@]}; do
        local -n pending_volume="$v"
        # This condition is meant to check for deleting an existing volume before creating
        # Should not be used with rm or the second volume action will fail, because it would be deleted twice
        if [[ $rm_existing_volumes == true ]] && [[ $action != "rm" ]]; then
            podman volume exists "$pending_volume" && podman volume rm "$pending_volume" 1> /dev/null
        fi
        podman volume "$action" "$pending_volume" || return 1
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

# create_all
# arguments: 2
# 1) Default network name - space seperated string of namerefs; Used by registry, server nodes
# 2) kubevirt network name - space seperated string of namerefs; Used by created kubevirt vms
# 2) cluster_name - space seperated string of namerefs; Name of cluster to create
# 4) cluster_config k3d yaml configuration file location
# 5) Optional: volumes - space seperated string of namerefs, gets converted into an array; containing the name of all volumes to be created
# 6) Optional: rm_volumes - boolean; Will delete volumes before attempting to create them
#    Does not return an error if the volume doesn't exist
#    Required when used with volumes option
create_all() {
    local -n default_network_name="$1"
    local -n kubevirt_network_name="$2"
    local -n cluster_name="$3"
    local -n k3d_config_file="$4"
    read -ar volumes <<< "${5:-""}"
    local -rt rm_volumes="${6}"

    create_networks default_network_name \
                 kubevirt_net

    manage_volumes "create" \
                    volumes \
                    rm_volumes

    manage_registry "create" \
                    REGISTRY \
                    CLUSTER_NETWORK_NAME_NODES

    create_k3d cluster_name \
                k3d_config_file

    succeed
}

delete_all() {
    local -n cluster="$1"
    local -n registry="$2"
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
    if ! check_existance "registry" "$1"; then
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
    if check_existance "registry" "$1"; then
        return 1
    elif ! check_existance "network" "$2"; then
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
    # TODO add variable output specifying if an argument is implimented or not
    echo "${0} < show-env
                | create-all
                | delete-all
                | recreate-all
                | volumes-create
                | volumes-rm
                | copy-manifests
                | network-create
                | network-rm
                | registry-create
                | registry-delete
                | copy-manifests
                | token-update-new
                | registry-delete
                | registry-create >"
}

manage_networks() {
    local action="$1"
    shift
    case $action in
    "create")
        created_networks="$(create_networks "${@}")"
        log "Succsfully created networks: \"$created_networks\""
    ;;
    "rm")
        deleted_networks="$(rm_networks "${@}")"
        log "Successfully deleted networks \"$deleted_networks\""
    ;;
    esac
}

# rm_networks
# arguments: any
# @) networks - Space seperated string of networks, gets parsed into an array;
#      Networks to rm
rm_networks() {
    read -a networks <<< "$@"

    if [[ -z ${networks[*]} ]]; then
        return 1
    fi

    local -a nets_del
    for n in ${networks[@]}; do
        local -n net="$n"
        if podman network exists "$net"; then
            nets_del+=("$(podman network rm "$net")")
        fi
    done

    echo "${nets_created[*]/ / /' '}"
}

# create_networks
# arguments: 10
# 1) default_net_name - string; Name of default network
# 2) kubevirt_net_name - string; Used by created kubevirt vms
# 3) service_net_name - string; Kubernetes service network
# 4) pod_net_name - string; Kubernetes service network
# 5) default_net_subnet - string; Kubernetes service network
# 6) kubevirt_net_subet - string; Kubernetes service network
# 7) service_net_subnet - string; Kubernetes service network
# 8) pod_net_subnet - string; Kubernetes service network
# 9) cluster - string; Name of cluster, used for network labels
# 10) cluster_instance - string; Name of cluster, used for network labels
create_networks() {
    local -n default_net_name="$1"
    local -n kubevirt_net_name="$2"
    local -n service_net_name="$3"
    local -n pod_net_name="$4"
    local -n default_net_subnet="$5"
    local -n kubevirt_net_subet="$6"
    local -n service_net_subnet="$7"
    local -n pod_net_subnet="$8"
    local -n cluster="$9"
    local -n cluster_instance="${10}"

    local -r default_net_interface="k3d0"
    local -r kubevirt_net_interface="k3d1"
    local -r service_net_interface="k3d2"
    local -r pod_net_interface="k3d3"

    local -a created_networks=()

    podman network create \
                    --subnet="$default_net_subnet" \
                    --interface-name="$default_net_interface" \
                    --label=name="$default_net_name" \
                    --label=cluster="$cluster" \
                    --label=part-of="$cluster" \
                    --label=instance="$cluster_instance" \
                    "$default_net_name" && created_networks+=("$default_net_name")

    podman network create \
                    --subnet="$kubevirt_net_subet" \
                    --interface-name="$kubevirt_net_interface" \
                    --label=name="$kubevirt_net_name" \
                    --label=cluster="$cluster" \
                    --label=part-of="$cluster" \
                    --label=instance="$cluster_instance" \
                    "$kubevirt_net_name" && created_networks+=("$kubevirt_net_name")

    podman network create \
                    --subnet="$service_net_subnet" \
                    --interface-name="$service_net_interface" \
                    --label=name="$service_net_interface" \
                    --label=cluster="$cluster" \
                    --label=part-of="$cluster" \
                    --label=instance="$cluster_instance" \
                    "$service_net_name" && created_networks+=("$kubevirt_net_name")

    podman network create \
                    --subnet="$pod_net_subnet" \
                    --interface-name="$pod_net_interface" \
                    --label=name="$pod_net_name" \
                    --label=cluster="$cluster" \
                    --label=part-of="$cluster" \
                    --label=instance="$cluster" \
                    --label=cluster="$cluster_instance" \
                    "$pod_net_name" && created_networks+=("$pod_net_name")

    echo "${created_networks[*]}"
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
    local type="$1"
    local -n c="$2"
    local -n r="$3"
    local -n pending_volumes="$4"

    if [[ $type == "registry" ]]; then
        manage_registry "delete" \
                        r
    elif [[ $type == "cluster" ]]; then
        manage_cluster_delete c
    elif [[ $type == "all" ]]; then
        manage_cluster_delete c
        manage_registry "delete" \
                        r
        manage_volumes "delete" \
                        "$pending_volumes"
    else
        log "unknown component type: ${type}"
        return 1
    fi

    return 0
}

manage_cluster() {
    local -n action="$1"
    local -n cluster="$2"

    if [[ $action == "create" ]]; then
        manage_cluster_create "$cluster"
    fi
}

manage_cluster_create() {
    # TODO inhert name of var above rather than using var reference here
    local -n cluster="$1"
}

manage_cluster_delete() {
    local -n c="$1"
    if ! check_existance "cluster" "$c"; then
        log "failed to find cluster \"$c\""
        return 1
    fi

    if ! k3d cluster delete "$c"; then
        log "failed to delete cluster \"$c\""
        return 1
    fi
}

# check_existance 
# arguments:
# 1) Component type - string
# 2) Name of component to check
check_existance() {
    local type="$1"
    local -n want="$2"
    if [[ $type == "cluster" ]]; then
        k3d cluster list "$want" > /dev/null || return 1
    elif [[ $type == "registry" ]]; then
        k3d registry list "$want" > /dev/null || return 1
    fi
}


# verify_config_files
# arguments:
# 1) default_cluster_env - Path to environment file
# 3) k3d_config - string; Path to k3d configuration file
verify_config_files() {
    local -r user_cluster_env="$1"
    local -r k3d_config="$3"
    if [[ ! -f $user_cluster_env ]]; then
        return 1
    elif [[ ! -f  $user_cluster_env ]]; then
        return 1
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

# DEVELOPMENT_ENVIRONMENT="bootstrap/config/env/bootstrap-cluster-k3d.dev.env"
declare -rt DEVELOPMENT_ENVIRONMENT_FILE="bootstrap/config/env/bootstrap-cluster-k3d.dev.env"
# PRODUCTION_ENVIRONMENT="bootstrap/config/env/bootstrap-cluster-k3d.env"
declare -rt PRODUCTION_ENVIRONMENT_FILE="bootstrap/config/env/bootstrap-cluster-k3d.env"
# K3D_CONFIG_LOCATION="bootstrap/config/bootstrap-cluster-k3d.yaml"
declare -rt K3D_CONFIG_FILE="bootstrap/config/bootstrap-cluster-k3d.yaml"
# NULL default empty null value for unset variables
declare -rt NULL=""
# BOOLEAN False
declare -rt BOOL_FALSE=false
# BOOLEAN True
declare -rt BOOL_TRUE=true
# User provided option Flag 1
declare -rt USER_OPTION_1="$1"
# FLAG_HELP - Default value to use if USER_OPTION_1 is unset
# causes print usage then exit
declare -rt FLAG_HELP
# DEVELOPEMENT_CLUSTER
# Used to set development or production file to use
# Cannot be set in the env file passed to main
#
# To create a production cluster, override the shell script's environment
declare -rt DEVELOPEMENT_MODE=${DEVELOPMENT_MODE:=true}

if [[ $DEVELOPEMENT_MODE == false ]]; then
    ENVIRONMENT_FILE=PRODUCTION_ENVIRONMENT_FILE
fi
echo "DEVELOPMENT_MODE: "

case "$DEVELOPEMENT_MODE" in
    true)
        ENVIRONMENT_FILE="PRODUCTION_ENVIRONMENT_FILE"
    ;;
    false)
        ENVIRONMENT_FILE="DEVELOPMENT_ENVIRONMENT_FILE"
    ;;
    *)
        abort "DEVELOPMENT_MODE unknown value"
    ;;
esac

#init_main 
# Initialize's environment for main
init_main \
    "USER_OPTION_1" \
    "${ENVIRONMENT_FILE}" \
    "K3D_CONFIG_FILE" \
    "$DEVELOPEMENT_MODE"
