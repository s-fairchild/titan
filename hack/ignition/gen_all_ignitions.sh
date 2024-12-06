#!/bin/bash
# Recursively generate all ignition files

set -o nounset \
    -o errexit

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

main() {
    local -r main_butane="$1"

    # shellcheck disable=SC2034
    local -a ign_merge_files
    gen_merge_ignitions "$main_butane" ign_merge_files

    gen_main_butane "$main_butane" ign_merge_files 
    # TODO gen_main_butane
    # cleanup merge ignitions and main butane afterwards
    # TODO use a temp directory
}

# gen_merge_configs()
gen_merge_ignitions() {
    log "starting"

    # shellcheck disable=SC2034
    gather_butane_files "$1" "$2"

    gen_all_ignitions "$2"
}

declare lib
lib="hack/lib/util.sh"
if [ -f "$lib" ]; then
    # shellcheck source=../lib/util.sh
    source "$lib"
else
    echo "$lib not found. Are you in the repository root?"
    exit 1
fi

lib="hack/ignition/lib/lib.sh"
if [ -f "$lib" ]; then
    # shellcheck source=lib/lib.sh
    source "$lib"
else
    echo "$lib not found. Are you in the repository root?"
    exit 1
fi

main "$@"
