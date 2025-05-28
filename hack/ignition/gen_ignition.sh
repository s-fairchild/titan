#!/bin/bash
# Recursively generate all ignition files

set -o nounset \
    -o errexit

if [ -n "${DEBUG:-}" ]; then
    set -x
else
    # Leave temporary butane file for review
    trap "cleanup TEMP_DATA" 1 2 3 6 EXIT
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
# 2) out_file - string; optional, path to write ignition file to
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

declare lib_sh="hack/ignition/lib/lib.sh"
if [ -f "$lib_sh" ]; then
    # shellcheck source=lib/lib.sh
    source "$lib_sh"
else
    echo "$lib_sh not found. Are you in the repository root?"; exit 1
fi

# shellcheck disable=SC2034
declare -a TEMP_DATA

main "$@"
