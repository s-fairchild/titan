#!/bin/bash

# gen_all_ignitions()
# args:
# 1) arr - nameref; array containing all butane files to be processed for merging into main config
# TODO rename this function
gen_all_ignitions() {
    local -n arr="$1"
    log "starting"

    # shellcheck disable=SC2068
    for i in ${!arr[@]}; do
        conf="${arr[$i]}"
        log "Generating ignition from $conf"
        arr[i]="$(gen_ignition "$conf")"
    done
}

# gen_ignition()
# args:
# 1) $1 - string; butane file to process
gen_ignition() {
    butane -srp --files-dir=deploy "$1"
}

# gen_main_ignition()
# args:
# 1) main - string; main butane file path
# 2) ignitions_merge - nameref; array of ignition file contents to insert into .ignition.config.merge[$i].inline
# 3) ign_out - nameref; empty, for returning the tmp file path
gen_main_ignition() {
    local main="$1"
    # Is this useful? ignition files will be expected to appear in the same place for deploying
    local -n ign_out="$3"
    log "starting"

    local relative_tmp_butane_file
    gen_main_butane "$main" "$2" relative_tmp_butane_file

    log "$relative_tmp_butane_file"

    # shellcheck disable=SC2034
    if ! ign_out="$(gen_ignition "$relative_tmp_butane_file")"; then
        abort "failed to generate ignition from deploy/${relative_tmp_butane_file}"
    fi
}

# gen_merge_configs()
# args:
# 1) main_bu - string; Butane file to parse for configs
# 2) files - nameref; Empty array, populated with butane config files
gen_merge_ignitions() {
    log "starting"

    # shellcheck disable=SC2034
    gather_butane_files "$1" "$2"
    gen_all_ignitions "$2"
}

# butane is only used by ignition.sh
lib="hack/ignition/lib/butane.sh"
if [ -f "$lib" ]; then
    # shellcheck source=butane.sh
    source "$lib"
else
    echo "$lib not found. Exiting."
    exit 1
fi

# included to provide definitions for shellcheck
lib="hack/lib/util.sh"
if [ -f "$lib" ]; then
    # shellcheck source=../../lib/util.sh
    source "$lib"
else
    echo "$lib not found. Are you in the repository root?"
    exit 1
fi
