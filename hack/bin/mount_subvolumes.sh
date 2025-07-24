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

    env_file="${user_options["$CONFIG_KEY_ENV_FILE"]}"
    if [ -f "$env_file" ]; then
        log "Sourcing the provided environment file $env_file..."
        # shellcheck source=../../docs/examples/archlinuxarm_subvolumes.env
        source "$env_file"
    fi

    local -r root_filesystem_target="/mnt/root"
    local boot_mount_target="/mnt/boot"

    user_verify_mounts SUBVOLUME_MOUNT_ORDER \
                SUBVOLUMES \
                user_options \
                "$root_filesystem_target" \
                "$boot_mount_target"

    local btrfs_mount_options="defaults,noatime,autodefrag,compress=zstd:3,x-systemd.device-timeout=0"
    mount_partition "${user_options["$CONFIG_KEY_ROOT_PARTITION"]}" \
                     "$root_filesystem_target" \
                     "$btrfs_mount_options"
                     

    subvolumes_create SUBVOLUME_MOUNT_ORDER \
                      "$root_filesystem_target"
    
    umount_partition "$root_filesystem_target"

    mount_subvolumes SUBVOLUMES \
                     SUBVOLUME_MOUNT_ORDER \
                     "${user_options["$CONFIG_KEY_ROOT_PARTITION"]}" \
                     "$root_filesystem_target" \
                     "$btrfs_mount_options"

    mount_partition "${user_options["$CONFIG_KEY_BOOT_PARTITION"]}" "$boot_mount_target"

    tarball_download_unpack "$root_filesystem_target" \
                            "$boot_mount_target" \
                            "${user_options["$CONFIG_KEY_TARBALL"]:-"$TARBALL_DOWNLOAD"}" \
                            TMP_DATA

    umount_partition "$boot_mount_target"
    local -r boot_mount_target="/$root_filesystem_target/boot"
    mount_partition "${user_options["$CONFIG_KEY_BOOT_PARTITION"]}" "$boot_mount_target"

    fstab_write "$root_filesystem_target"

    log "$root_filesystem_target is ready for chroot"
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
    sudo umount -vqA $@
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

usage() {
    # TODO populate usage message
    log "usage message"
}

declare -r utils="hack/lib/util.sh"
declare -r bsdtar_lib="hack/lib/archlinuxarm_bsdtar.sh"
declare -r options_lib="hack/lib/archlinuxarm/options.sh"

if [ ! -f "$utils" ]; then
    echo "$utils not found. Are you in the repository root?"; exit 1
elif [ ! -f "$bsdtar_lib" ]; then
    abort "$bsdtar_lib not found. Are you in the repository root?"
elif [ ! -f "$options_lib" ]; then
    abort "$options_lib not found. Are you in the repository root?"
fi

# shellcheck source=../lib/util.sh
source "$utils"
# shellcheck source=../lib/archlinuxarm_bsdtar.sh
source "$bsdtar_lib"
# shellcheck source=../lib/archlinuxarm/options.sh
source "$options_lib"

declare -a TMP_DATA
trap "cleanup TMP_DATA" 1 2 3 6 EXIT

main "$@"
