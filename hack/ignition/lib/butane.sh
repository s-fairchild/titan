#!/bin/bash
# Library of tools used by ignition butane_*.sh scripts

# gather_butane_files()
# 
# Args:
# 1) main_bu - string; Butane file to parse for configs
# 2) files - nameref; Empty array, populated with butane config files
gather_butane_files() {
    local -r main_bu="$1"
    local -n files="$2"
    log "starting"

    local raw_butane_files
    # TODO simplify conversion into array by using yq output formatting options
    raw_butane_files="$(yq '.ignition.config.merge[]' "$main_bu")"
    check_empty_str "$raw_butane_files"
    
    # remove local_ prefix
    local -r sed_opt_strip_local_prefix='s/local_//'
    # convert : to _
    local -r sed_opt_trim_colon='s/: /_/g'
    local -r sed_val_opts="${sed_opt_trim_colon};${sed_opt_strip_local_prefix}"
    
    # Get files in full path format
    sed_out="$(sed "${sed_val_opts}" <<< "${raw_butane_files[*]}")"

    # shellcheck disable=SC2034
    mapfile -t files <<< "${sed_out}"
}

check_empty_str() {
    if [ -z "${1:-}" ]; then
        log ".ignition.config.merge is empty"
        return 1
    fi
}

# gen_main_ignition()
gen_main_butane() {
    local -r main="$1"
    local -n merge_configs="$2"
    log "starting"

    
    local -i main_merge_len
    main_merge_len="$(yq '(.ignition.config.merge | length)' "$main")"
    if [ "${#merge_configs[@]}" -ne "$main_merge_len" ]; then
        abort "$main configs $main_merge_len != ${#merge_configs[@]}"
    fi

    working_butane="$(yq "$main")"
    prefix="$(get_merge_file_prefix "$main")"
    final_main_butane="deploy/ignition/${prefix}main.bu"

    # shellcheck disable=SC2068
    for i in ${!merge_configs[@]}; do
        merge_file="local: ${prefix}$(gen_merge_filename "${merge_configs[$i]}")"
        export pathEnv=".ignition.config.merge[$i]" valueEnv="$merge_file"
        working_butane="$(yq -e=1 'eval(strenv(pathEnv)) = env(valueEnv)' <<< "$working_butane")"
    done

    echo "$working_butane" > "$final_main_butane"
}

# butane()
butane() {
    image="quay.io/coreos/butane:release"

    podman run \
        --name butane \
        --security-opt label=disable \
        -i \
        --rm \
        -v "${PWD}/deploy":/data \
        -w /data \
        "$image" \
        "$@"
}
