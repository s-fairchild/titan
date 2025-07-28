#!/bin/bash

mount_partition() {
    local part="$1"
    local target="$2"
    local o="${3:-}"
    log "starting"

    if [ -n "$o" ]; then
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

subvolumes_mount() {
    local -n subvols="$1"
    local -n subvol_order="$2"
    local root_part="$3"
    local root_target="$4"
    local opts="$5"
    log "starting"

    # shellcheck disable=SC2068
    # shellcheck disable=SC2154
    for subvol in ${subvol_order[@]}; do
        # shellcheck disable=SC2154
        target="/mnt/root/${subvols["$subvol"]/'@'/}"
        sudo mkdir -p "$target"
        mount_partition "$root_part" "$target" "$opts,subvol=$subvol"
    done
}


# subvolumes_create()
# TODO set root subvolume @ as the default subvolume
# btrfs subvol set-default @
subvolumes_create() {
    local -n subvol_order="$1"
    local root_target="$2"
    log "starting"

    # shellcheck disable=SC2068
    for subvol in ${subvol_order[@]}; do
        new_subvol="$root_target/$subvol"
        sudo btrfs subvolume create "$new_subvol"
    done
}
