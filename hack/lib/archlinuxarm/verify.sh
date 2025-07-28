#!/bin/bash

user_verify_mounts() {
    local -n subvol_order="$1"
    local -n subvols="$2"
    local -n opts="$3"
    local root_target="$4"
    local boot_target="$5"
    log "starting"

    log "Device: ${opts["$CONFIG_KEY_ROOT_PARTITION"]} target=$root_target"
    log "Device: ${opts["$CONFIG_KEY_BOOT_PARTITION"]} target=$boot_target"

    # shellcheck disable=SC2068
    for subvol in ${subvol_order[@]}; do
        echo -e "subvolume: $subvol \t\t target=$root_target/${subvols["$subvol"]}"
    done

    read -n1 -t 60 -p "${FUNCNAME[0]}: Do you want to continue? (y/n): "

    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        abort
    fi

    # Provide line break for output readability
    echo ""
}

# Supported board types

# declare -r RPI_MODEL_4="rpi4"
declare -r RPI_MODEL_4="rpi4"
# declare -r RPI_MODEL_5="rpi5"
declare -r RPI_MODEL_5="rpi5"

# declare -r SUPPORTED_BOARDS="($RPI_MODEL_4B|$RPI_MODEL_5)"
declare -r SUPPORTED_BOARDS="($RPI_MODEL_4|$RPI_MODEL_5)"

board_support_check() {
    if [[ ! $1 =~ $SUPPORTED_BOARDS ]]; then
        board_support_list
        abort "$1 board type not supported."
    fi
}

is_ssh_key_public() {
    check_file_exists "$1" || abort "$1 ssh key does not exist"

    if [[ ! $1 =~ .*\.pub$ ]]; then
        abort "$1 is not a public key. Please provide a public ssh key."
    fi
}
