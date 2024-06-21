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
            echo "Unkown option \"$1\""
    esac
}

validate_ignition() {
    local -n ign="$1"
    # TODO add log and abort functions
    podman run \
        --pull=newer \
        --rm \
        -i \
        --volume "${PWD}":/pwd \
        --workdir /pwd \
        quay.io/coreos/ignition-validate:release \
        - < "$ign"
}

generate_all_ignition() {
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
        fix_fcontext ign
    done
}

gen_ignition() {
    local -n butane_file="$1"
    local -n ignition_file="$2"
    
    echo "Generating \"$ignition_file\" from \"$butane_file\""
    # TODO add log and abort functions
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
    chcon --verbose \
          --type \
          svirt_home_t \
          "$f"
}

declare -r butane_ignition_files="hack/butane_ignition_files.env"
if [ -f "$butane_ignition_files" ]; then
    # shellcheck source=../hack/butane_ignition_files.env
    source "$butane_ignition_files"
else
    echo "Missing $butane_ignition_files, aborting"
    exit 1
fi

main "$@"
