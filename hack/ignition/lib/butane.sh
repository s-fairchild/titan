#!/bin/bash
# tools to be used for processing ignition files
# should only be used by scripts in hack/ignition/lib

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
    raw_butane_files="$(yq -e=1 '.ignition.config.merge[]' "$main_bu")"
    
    # remove local_ prefix
    local -r sed_opt_strip_local_prefix='s/inline_//'
    # convert : to _
    local -r sed_opt_trim_colon='s/: /_/g'
    local -r sed_val_opts="${sed_opt_trim_colon};${sed_opt_strip_local_prefix}"
    
    # Get files in full path format
    sed_out="$(sed "${sed_val_opts}" <<< "${raw_butane_files[*]}")"

    # shellcheck disable=SC2034
    mapfile -t files <<< "${sed_out}"
}

# gen_main_butane()
# args
# 1) m - string; main butane file
# 2) ignitions_merge - nameref; array of ignition file contents to insert into .ignition.config.merge[$i].inline
# 3) tmp_file_path - nameref; empty, for returning the tmp file path
gen_main_butane() {
    local -r m="$1"
    local -n ignitions_merge="$2"
    log "starting"

    verify_config_dest_length "$2"
    working_butane="$(yq "$m")"

    # shellcheck disable=SC2068
    for i in ${!ignitions_merge[@]}; do
        merge_ignition="${ignitions_merge[$i]}"
        export pathEnv=".ignition.config.merge[$i].inline" valueEnv="$merge_ignition"
        # It maybe a good idea to encode these as a data url in base64
        working_butane="$(yq -e=1 'eval(strenv(pathEnv)) = strenv(valueEnv)' <<< "$working_butane")"
    done

    write_tmp_butane "$m" working_butane "$3"
}

# write_tmp_butane()
# args
# 1) $1 - string; butane file path
# 2) butane_contents - nameref; final butane file contents
# 3) tmp_file_path - nameref; empty, for returning the tmp file path
write_tmp_butane() {
    local -n butane_contents="$2"
    local -n tmp_file_path="$3"

    prefix="$(get_merge_file_prefix "$1")"
    tmp_file_path="$(mktemp -p deploy/butane -d --suffix=.tmp -t ".${prefix}_main_butane.XXX")"
    tmp_file_path="$tmp_file_path/${prefix}_main.bu"
    echo "$butane_contents" > "$tmp_file_path"

    TEMP_DATA+=("$tmp_file_path" "$(dirname "$tmp_file_path")")
    # fix up for butane container working directory
    tmp_file_path="${tmp_file_path}"
}


# verify_config_dest_length()
# Compares an array to an integer, aborts if they aren't equal
# args
# 1) configs - array
# 2) config_len - int; expected length of configs
verify_config_dest_length() {
    local -n configs="$1"
    local -i config_len

    config_len="$(yq '(.ignition.config.merge | length)' "$m")"
    if [ "${#configs[@]}" -ne "$config_len" ]; then
        abort "$m configs $config_len != ${#configs[@]}"
    fi
}

# butane()
# runs ignition in a container with image quay.io/coreos/butane:release
# args:
# @) all arguements are passed to the container
butane() {
    image="quay.io/coreos/butane:release"

    podman run \
        --name butane \
        --security-opt label=disable \
        -i \
        --rm \
        -v "${PWD}/deploy/butane":/data/deploy/butane:O \
        -v "${HOME}/.ssh":/data/deploy/keys:O \
        -w /data \
        "$image" \
        "$@"
}
