#!/bin/bash
# Utilies to be sourced for use in other scripts

# log()
# log is a wrapper for echo that includes the function name
# Args
# 1) msg - string
# 2) stack_level - int; optional, defaults to calling function
log() {
    local -r msg="${1:-"log message is empty"}"
    local -r stack_level="${2:-1}"
    echo "${FUNCNAME[${stack_level}]}: ${msg}"
}

# abort()
# abort is a wrapper for log that exits with an error code
abort() {
    local -ri origin_stacklevel=2
    log "${1}" "$origin_stacklevel"
    log "Exiting"
    exit 1
}

# yq()
# yq is a portable command-line data file processor (https://github.com/mikefarah/yq/) 
# See https://mikefarah.gitbook.io/yq/ for detailed documentation and examples.
#
# Use "yq [command] --help" for more information about a command.
yq() {
    image="docker.io/mikefarah/yq:latest"

           # -v yq_out:/workdir/out:z \
    podman run \
           --name yq \
           --security-opt label=disable \
           -i \
           --rm \
           --env-host \
           -v "${PWD}":/workdir \
           "$image" \
           "$@"
}

# TODO create a directory named prefix
get_merge_file_prefix() {
    basename "$(dirname "$1")"
}

# cleanup()
# useful to call via trap for cleaning up files/directories
# args:
# 1) trash - nameref; array of files/directories to delete
cleanup() {
    local -n trash="$1"
    log "starting"

    # shellcheck disable=SC2068
    for t in ${trash[@]}; do
        if [ -f "$t" ] || [ -d "$t" ]; then
            log "$t"
            rm -rf "$t"
        fi
    done
}

# check_dir_exists()
check_dir_exists() {
    [ -d "$1" ] || abort "Could not find $1"
}
