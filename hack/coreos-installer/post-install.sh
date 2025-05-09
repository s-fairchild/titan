#!/bin/bash

set -o nounset \
    -o errexit

main () {
    log "starting"
}

btrfs_create_subvols() {
    log "starting"
    
    btrfs subvolume create -p /var/local/lib/k3s/local-path/default
    btrfs subvolume create -p /var/local/lib/k3s/agent/local-path-appdata/local-path/appdata
    btrfs subvolume create -p /var/local/lib/k3s/agent/local-path-cctv/local-path/cctv
}

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

main
