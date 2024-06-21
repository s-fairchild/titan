#!/bin/bash
# Generate ingition files for deployment

set -o nounset \
    -o errexit

main() {

    case "$1" in
        "generate")
            if [ "$2" == "dev" ]; then
                generate_all_ign dev_files \
                                dev_final
            elif [ "$2" == "prod" ]; then
                generate_all_ign prod_files \
                                prod_final
            fi
            ;;
        "prod")
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

declare -r butane_ignition_files="hack/butane_ignition_files.env"
if [ -f "$butane_ignition_files" ]; then
    # shellcheck source=hack/butane_ignition_files.env
    source "$butane_ignition_files"
else
    echo "Missing $butane_ignition_files, aborting"
    exit 1
fi

main "$@"
