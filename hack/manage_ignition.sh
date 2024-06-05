#!/bin/bash
# Generate ingition files for deployment

set -o nounset \
    -o errexit

main() {

    case "$1" in
        "generate")
            # TODO make this cleaner by removing the if statement later
            if [ "$2" == "dev" ]; then
                generate_all_ignition dev_files \
                                dev_final
            elif [ "$2" == "prod" ]; then
            # TODO make this cleaner by removing the if statement later
                generate_all_ignition prod_files \
                                prod_final
            fi
            ;;
        "validate")
            # TODO make this cleaner by removing the if statement later
            if [ "$2" == "dev" ]; then
                validate_ignition ignition_cluster
            elif [ "$2" == "prod" ]; then
                validate_ignition ignition_cluster_dev
            fi
            ;;
        *)
            abort "Unkown option \"$1\""
    esac
}

validate_ignition() {
    local -n ign="$1"
    log "starting"

    podman run \
        --pull=newer \
        --rm \
        -i \
        --volume "${PWD}":/pwd \
        --workdir /pwd \
        quay.io/coreos/ignition-validate:release \
        - < "$ign"
    
    log "ignition validated $ign"
}

generate_all_ignition() {
    local -n files="$1"
    local -n final="$2"
    log "starting"

    # shellcheck disable=SC2068
    for b in ${!files[@]}; do
        ign="${files[$b]}"
        gen_ignition b ign
    done

    # shellcheck disable=SC2068
    for b in ${!final[@]}; do
        ign="${final[$b]}"
        gen_ignition b ign
        fix_fcontext ign
    done
}

gen_ignition() {
    local -n butane_file="$1"
    local -n ignition_file="$2"
    
    log "Generating \"$ignition_file\" from \"$butane_file\""
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

fix_fcontext() {
    local -n f="$1"
    log "starting"

    chcon --verbose \
          --type \
          svirt_home_t \
          "$f"
}

declare -r utils="hack/utils.sh"
if [ -f "$utils" ]; then
    # shellcheck source=utils.sh
    source "$utils"
fi

declare -r env_file="hack/env/manage_ignition.env"
if [ -f "$env_file" ]; then
    # shellcheck source=env/manage_ignition.env
    source "$env_file"
else
    abort "Missing $env_file, aborting"
fi

main "$@"
