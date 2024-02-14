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
    local CLUSTER_SUBNET_NODES="${CLUSTER_SUBNET_NODES:-10.94.0.0/16}"
    local CLUSTER_SUBNET_VMS="${CLUSTER_SUBNET_VMS:-10.93.0.0/16}"
    local CLUSTER_SUBNET_SERVICES="${CLUSTER_SUBNET_SERVICES:-10.46.0.0/16}"
    local ROLLBACK=${ROLLBACK:-false}
    # TODO allow overriding vars set in .env with cmd line arg for cluster name
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
    local -r node_server_0="k3d-${CLUSTER_MANAGER}-server-0"

    if [[ ${REMOTE_INSTALL} == "true" ]]; then
        podman() {
            command podman -r "${@}"
        }
    fi

    local -n arg1="${1:-help}"
    # TODO turn this into a getopts case switch loop
    # TODO add a --debug option for adding `set -T -x`
    case $arg1 in
    "create-all")
        create_all node_server_0
        ;;
    "delete-all")
        delete_all
        ;;
    "recreate-all")
        delete_all
        create_all node_server_0
        ;;
    "create-volumes")
        manage_volumes "create"
        ;;
    "copy-manifests")
        copy_all_to_node node_server_0
        ;;
    "get-defaults")
        log "Default Environment: "
        local -p
        ;;
    "help")
        usage
        ;;
    *)
        log "${0}: Unkown arg \"${1}\""
        abort usage
        ;;
    esac
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

copy_all_to_node() {
    local -r err="Node name must be provided"
    local -n node="$1"

    local -r opt_cluster="clusterconfig"
    local -r opt_workloads="apps"
    local -r opt_skip="skip"

    local -a opt_enabled=(
        "$opt_cluster"
    )

    # shellcheck disable=SC2068
    for option in ${opt_enabled[@]}; do
        copy_to_node "$node" "$option"
    done
}

copy_to_node() {
    local n="${1}"
    local opt="${2}"
    local -r node_manifests_path="/var/lib/rancher/k3s/server/manifests/compute"
    local -r node_manifests_skip_path="/var/lib/rancher/k3s/server/manifests/skip"
    local local_manifests_path 
    local_manifests_path="$(pwd)"

    local -a manifests
    if [[ $opt == "$opt_cluster" ]]; then
        manifests=(
            # Required for k3s install, probably not k3d cluster
            coredns
            nginx
            traefik
        )
        local_manifests_path+="/${opt_cluster}"
    # Not implimented but not currently used, future plans are to load this into a volume
    # attached to the bootstrap cluster for use in creating workload clusters
    elif [[ $opt == "$opt_workloads" ]]; then
        abort "argument \"$opt\" is not supported"
        manifests=(
            jellyfin
            motion
            pihole
            v4l2rtspserver
        )
        local_manifests_path+="/${opt_workloads}"
    elif [[ $opt == "$opt_skip" ]]; then
        local_manifests_path+="${opt_cluster}/${opt_skip}"
    else
        abort "option: \"$opt\" is unkown"
    fi
    local -r local_manifests_path

    # change to debug line
    log "working directory: ${local_manifests_path}"

    local tarball 
    local kustom=false
    local node_path
    if [[ $opt == "$opt_workloads" ]]; then
        node_path="$node_manifests_path"
        kustom=true
    # TODO set skip as an enabled file option
    elif [[ $opt == "$opt_skip" ]]; then
        node_path="$node_manifests_skip_path"
    fi
    local -r kustom node_path
    generate_manifests_tar manifests kustom tarball local_manifests_path
    
    log "Attempting to podman cp \"$opt\" manifests now..."
    podman cp - "${n}:${node_path}" <<< "$tarball"
    log "Completed uploading \"$opt\" manifests."
}

#######################################
# Get configuration directory.
# References:
#   arguement 3
# Arguments:
#   1) Array of directories containing kustomize yaml files and other manifests to be processed by "oc kustomize ${enabled_dirs[@]}"
# Outputs:
#   Modifies reference variable provided in argument 3, populating it with the tar archive
#######################################
generate_manifests_tar() {
    local -n enabled_dirs="$1"
    local -n o_kustomize="$2"
    local -n tar_archive="$3"
    local -n path="$4"
    local -i enabled_len=${#enabled_dirs[@]}
    local tmp
    tmp="$(mktemp -d)"

    # TODO move file extensions enabled up one level in scope, set/unset enabled/disabled options respectively
    local -ar file_extensions=(
        '*.tgz'
        '*.yaml'
        '*.skip'
    )
    local -r tar_archive_file="${tmp}/$(date --rfc-3339=minutes).tar"
    local -a files_to_archive
    if [[ $enabled_len -eq 0 ]] && [[ $o_kustomize == true ]]; then
        abort "input manifests cannot be empty with argument \"$o_kustomize\" provided input \$enabled_dirs length is zero: $enabled_len"
    elif [[ $o_kustomize == false ]]; then
        pushd "$path" || abort "failed to change directory into \"$path\""
        log "Creating tar archive now "
        for ext in "${file_extensions[@]}"; do
            files="$(find "$path" -name "$ext")"
            read -a arr <<< $files
            files_to_archive+=("${arr[@]}")
        done
        popd
        tar cvf "$tar_archive_file" "${files_to_archive[@]}"
    # Not Implimenented
    elif [[ $o_kustomize == true ]]; then
        abort "loading kustomize files is not implimented yet"
    fi

    if [[ ! -f $tar_archive_file ]]; then
        abort "generated tar archive \"$tar_archive_file\" doesn't exist"
    fi

    tar -tf "$tar_archive_file" > /dev/null || abort "Testing $tar_archive_file failed"

    # TODO set as debug log message
    log "Extracting tar archive to variable reference in \"\$3\""
    local -r tar_error_log="$tmp/tar_failure_log_$(date +%F-%T)"
    if tar_archive="$(tar xf "$tar_archive_file" -O 2> "$tar_error_log")" && error_log_check "$tar_error_log"; then
        return 0
    else
        log "failed to create tar archive, log located at \"$f\""
        log "deleting temporary archive \"$tar_archive_file\""
        rm "$tar_archive_file"
        return 1
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

create_all() {
    local -n node_copy_to="$1"
    init_network
    manage_volumes "create"
    # TODO include a recreate option for this script to optionally delete components
    manage_registry "$REGISTRY" "${CLUSTER_NETWORK_NAME_NODES}" "create"
    create_k3d "${CLUSTER_MANAGER}" "${k3d_config}"
    copy_all_to_node "$node_copy_to"
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
    echo "${0} < delete-all | create-all | create-volumes | recreate-all | copy-manifests>"
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

log() {
    local msg="${1:?Log message cannot be unset}"
    local stack_level="${2:-1}"
    echo "${FUNCNAME[${stack_level}]}: ${msg}"
}

abort() {
    log "${1}" "2"
    exit 1
}

option="$1"
main option
