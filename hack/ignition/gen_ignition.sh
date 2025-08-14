#!/bin/bash
# Recursively generate all ignition files

set -o nounset \
    -o errexit

DEBUG="${DEBUG:-"false"}"
if [ "$DEBUG" == "true" ]; then
    set -x
fi

main() {
    local -r main_butane="$1"
    local -r output_file="${2:-""}"

    # fail early if expected output directory is missing
    if [ -n "$output_file" ]; then
        check_dir_exists "$(dirname "$output_file")"
    fi

    # shellcheck disable=SC2034
    local -a ignitions
    gen_merge_ignitions "$main_butane" ignitions

    # shellcheck disable=SC2034
    local main_ignition
    gen_main_ignition "$main_butane" ignitions main_ignition

    log "Done"
    # TODO add step to replace all variables in butane files processed by yq, Fail if unset
    output_ignition main_ignition "$output_file"
}

# output_ignition()
# 
# args:
# 1) ign - nameref; output ignition file
# 2) out_file - string; path to write ignition file to. Pass "" for stdout
output_ignition() {
    local -n ign="$1"
    local -r out_file="$2"

    if [ -n "$out_file" ]; then
        log "Writing ignition file to $out_file"
        echo "$ign" > "$out_file"
    else
        echo "$ign"
    fi
}

declare lib_sh="hack/ignition/lib/ignition.sh"
if [ ! -f "$lib_sh" ]; then
    echo "$lib_sh not found. Are you in the repository root?"
    exit 1
fi
# shellcheck source=lib/ignition.sh
if ! source "$lib_sh"; then
    echo "Sourcing $lib_sh failed."
    exit 1
fi

# shellcheck disable=SC2034
# cleanup directory passed to trap
declare -a TEMP_DATA

# included to provide definitions for shellcheck
ignition_lib="hack/ignition/lib/ignition.sh"
if [ -f "$ignition_lib" ]; then
    # shellcheck source=lib/ignition.sh
    source "$ignition_lib"
else
    echo "$ignition_lib not found. Are you in the repository root?"
    exit 1
fi

main "$@"
