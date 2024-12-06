#!/bin/bash

# gen_all_ignitions()
gen_all_ignitions() {
    local -n arr="$1"
    log "starting"

    local -r prefix="$(get_merge_file_prefix "$f")"
    # shellcheck disable=SC2068
    for f in ${arr[@]}; do
        gen_ignition "$f" "$prefix"
    done
}

# gen_ignition()
gen_ignition() {
    f="$1"
    p="$2"

    ign_out="$(gen_merge_filename "$f")"


    full_out_path="ignition/${p}${ign_out}"
    log "Converting $f into ignition file $full_out_path"
    butane --files-dir=butane -o "$full_out_path" "$f"
}

gen_merge_filename() {
    sed 's/\//_/g;s/.bu/.ign/g' <<< "$1"
}

# TODO create a directory named prefix
get_merge_file_prefix() {
    echo "$(basename "$(dirname "$1")")_"
}

# ignition()
ignition() {
    image="quay.io/coreos/coreos-installer:release"

    podman run \
        --name ignition \
        --security-opt label=disable \
        -i \
        --rm \
        -v "${PWD}":/data \
        -w /data \
        "$image" \
        "$@"
}
