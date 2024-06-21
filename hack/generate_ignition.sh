#!/bin/bash
# Generate ingition files for deployment

set -o nounset \
    -o errexit

main() {

    case "$1" in
        "dev")
            generate_all_ign dev_files \
                            dev_final
            ;;
        "prod")
            generate_all_ign prod_files \
                            prod_final
            ;;
        *)
            echo "Unkown option \"$1\""
    esac
}

generate_all_ign() {
    local -n files="$1"
    local -n final="$2"
    # shellcheck disable=SC2068
    for b in ${!files[@]}; do
        ign="${files[$b]}"
        gen_ignition b ign
    done

    # shellcheck disable=SC2068
    for b in ${!final[@]}; do
        ign="${final[$b]}"
        gen_ignition b ign
    done
}

gen_ignition() {
    local -n butane_file="$1"
    local -n ignition_file="$2"
    
    echo "Generating \"$ignition_file\" from \"$butane_file\""
    podman run \
        --pull=newer \
        --interactive \
        --rm \
        --security-opt label=disable \
        --volume "${PWD}":/pwd \
        --workdir /pwd \
        quay.io/coreos/butane:release \
            --pretty \
            --strict \
            --files-dir deploy/ \
            "$butane_file" > "$ignition_file"
}

# Directories
declare -r deploy_dir="deploy"
declare -r config_dir="$deploy_dir/config"
declare ignition_dir="$deploy_dir/ignition"

# Production butane files
declare -r butane_users="$config_dir/users.bu"
declare -r butane_systemd="$config_dir/systemd.bu"
declare -r butane_storage="$config_dir/storage.bu"
declare -r butane_cluster="$config_dir/cluster.bu"
# Production ignition files
declare -r ignition_users="$ignition_dir/users.ign"
declare -r ignition_systemd="$ignition_dir/systemd.ign"
declare -r ignition_storage="$ignition_dir/storage.ign"
declare -r ignition_cluster="$ignition_dir/cluster.ign"

# Development butane files
declare -r butane_storage_dev="$config_dir/storage-dev.bu"
declare -r butane_cluster_dev="$config_dir/cluster-dev.bu"
# Development ignition files
declare -r ignition_storage_dev="$ignition_dir/storage-dev.ign"
declare -r ignition_cluster_dev="$ignition_dir/cluster-dev.ign"

declare -rA dev_files=(
    ["$butane_systemd"]="$ignition_systemd"
    ["$butane_users"]="$ignition_users"
    ["$butane_storage_dev"]="$ignition_storage_dev"
)

declare -rA dev_final=(
    ["$butane_cluster_dev"]="$ignition_cluster_dev"
)

declare -rA prod_files=(
    ["$butane_systemd"]="$ignition_systemd"
    ["$butane_users"]="$ignition_users"
    ["$butane_storage"]="$ignition_storage"
)

declare -rA prod_final=(
    ["$butane_cluster"]="$ignition_cluster"
)

main "$@"
