#!/bin/bash

mount_partition() {
    local part="$1"
    local target="$2"
    local o="${3:-}"
    log "starting"

    if [ -n "$3" ]; then
        local -a o=(
            "-o"
            "${o[@]}"
        )
    fi

    # shellcheck disable=SC2068
    sudo mount -v ${o[@]} "$part" "$target"
}

umount_partition() {
    # shellcheck disable=SC2068
    sudo umount -vqA $@
}
