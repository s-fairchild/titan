#!/bin/bash

set -o nounset \
    -o errexit

DEBUG="${DEBUG:-"false"}"

if [ "$DEBUG" == "true" ]; then
    set -x
fi

main() {
    local -A user_options
    collect_user_options user_options "$@"

    env_file="${user_options["$USER_ENV_FILE_KEY"]}"
    if [ -f "$env_file" ]; then
        log "Sourcing the provided environment file $env_file..."
        # shellcheck source=../../docs/examples/archlinuxarm_subvolumes.env
        source "$env_file"
    fi

    local -r root_filesystem_target="/mnt/root"
    local -r boot_mount_target="$root_filesystem_target/boot"

    user_verify_mounts SUBVOLUME_MOUNT_ORDER \
                SUBVOLUMES \
                user_options \
                "$root_filesystem_target" \
                "$boot_mount_target"

    local btrfs_mount_options="defaults,noatime,autodefrag,compress=zstd:3,x-systemd.device-timeout=0"
    mount_partition "${user_options["$ROOT_PARTITION_KEY"]}" \
                     "$root_filesystem_target" \
                     "$btrfs_mount_options"
                     

    subvolumes_create SUBVOLUME_MOUNT_ORDER \
                      "$root_filesystem_target"
    
    umount_partition "$root_filesystem_target"

    mount_subvolumes SUBVOLUMES \
                     SUBVOLUME_MOUNT_ORDER \
                     "${user_options["$ROOT_PARTITION_KEY"]}" \
                     "$root_filesystem_target" \
                     "$btrfs_mount_options"

    sudo mkdir "$boot_mount_target"
    # TODO mount boot under /mnt/boot to copy files to, then mount under the root subvolume afterwards
    mount_partition "${user_options["$BOOT_PARTITION_KEY"]}" \
                     "$boot_mount_target"

    fstab_write "$root_filesystem_target"

    umount_partition "$boot_mount_target"
}

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

mount_partition() {
    local part="$1"
    local target="$2"
    local o="${3:-}"
    log "starting"

    if [ -n "${3:-}" ]; then
        local -a o=(
            "-o"
            "${o[@]}"
        )
    fi

    # shellcheck disable=SC2068
    sudo mount -v ${o[@]} "$part" "$target"
}

umount_partition() {
    sudo umount -vqA "$1"
}

mount_subvolumes() {
    local -n subvols="$1"
    local -n subvol_order="$2"
    local root_part="$3"
    local root_target="$4"
    local opts="${5:-}"
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

fstab_write() {
    local target="$1"
    log "starting"

    # TODO include the mount options that are missing from the generated fstab file
    fstab="$(sudo genfstab -U "$target")"
    fstab="$(sed -e '/LABEL=zram0/ { N; d; }' <<< "$fstab")"
    etc="$target/etc"
    fstab_out="$etc/fstab"
    sudo mkdir -p "$etc"

    log "Writing fstab to $fstab_out"
    echo "$fstab" | sudo tee "$fstab_out" > /dev/null
}

user_verify_mounts() {
    local -n subvol_order="$1"
    local -n subvols="$2"
    local -n opts="$3"
    local root_target="$4"
    local boot_target="$5"
    log "starting"

    log "Device: ${opts["$ROOT_PARTITION_KEY"]} target=$root_target"
    log "Device: ${opts["$BOOT_PARTITION_KEY"]} target=$boot_target"

    # shellcheck disable=SC2068
    for subvol in ${subvol_order[@]}; do
        echo -e "subvolume: $subvol \t\t target=$root_target/${subvols["$subvol"]}"
    done

    read -n1 -t 60 -p "${FUNCNAME[0]}: Do you want to continue? (y/n): "

    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        abort
    fi

    echo ""
}

usage() {
    # TODO populate usage message
    log "usage message"
}

declare utils="hack/lib/util.sh"
if [ -f "$utils" ]; then
    # shellcheck source=../lib/util.sh
    source "$utils"
else
    echo "$utils not found. Are you in the repository root?"; exit 1
fi

# BOOT_PARTITION_KEY="boot_partition"
declare -r BOOT_PARTITION_KEY="boot_partition"
# ROOT_PARTITION_KEY="root_partition"
declare -r ROOT_PARTITION_KEY="root_partition"
# USER_ENV_FILE_KEY="user_env_file"
declare -r USER_ENV_FILE_KEY="user_env_file"

collect_user_options() {
    local -n config="$1"
    shift
    log "starting"

    optstring=":e:r:b:t:h"
    local OPTIND
    local options
    local user_env_file
    local root_partition
    local boot_partition

    while getopts ${optstring} options; do
        case $options in
            e)
                user_env_file="$OPTARG"
                log "environment file $user_env_file will be sourced."
                ;;
            r)
                root_partition="$OPTARG"
                log "$root_partition will be used for the root filesystem."
                ;;
            b)
                # ${string##*( )}"
                boot_partition="${OPTARG}"
                log "$boot_partition will be used for the boot partition."
                ;;
            h)
                usage
                ;;
            :)
                abort "Option -${OPTARG} requires an argument."
                ;;
            ?)
                abort
                ;;
        esac
    done

    config["$BOOT_PARTITION_KEY"]="$boot_partition"
    config["$ROOT_PARTITION_KEY"]="$root_partition"
    # shellcheck disable=SC2034
    config["$USER_ENV_FILE_KEY"]="$user_env_file"

}

main "$@"
