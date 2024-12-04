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
    local -a butane_files
    gather_butane_files "$main_butane" \
                         butane_files \

    environment="$(basename "$(dirname "$main_butane")")"
    gen_all_ignitions butane_files "$environment"
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
