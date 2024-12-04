#!/bin/bash

# gen_all_ignitions()
gen_all_ignitions() {
    local -n arr="$1"
    local -r env_prefix="$2"
    log "starting"

    # shellcheck disable=SC2068
    for f in ${arr[@]}; do
        gen_ignition "$f" "$env_prefix"
    done
}

# gen_ignition()
gen_ignition() {
    f="$1"
    prefix="$2"
    local ign_out
    ign_out="$(sed 's/\//_/g;s/.bu/.ign/g' <<< "$f")"
    # TODO create a directory named prefix
    full_out_path="ignition/${prefix}_${ign_out}"
    log "Converting $f into ignition file $full_out_path"
    butane --files-dir=butane -o "$full_out_path" "$f"
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
