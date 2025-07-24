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
    local -r boot_mount_target="/mnt/boot"

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

    mount_partition "${user_options["$BOOT_PARTITION_KEY"]}" "$boot_mount_target"

    tarball_download_unpack "$root_filesystem_target" "$boot_mount_target" "${user_options["$CONFIG_KEY_TARBALL"]:-"download"}" TMP_DATA

    umount_partition "$boot_mount_target"
    local -r boot_target_tmp="/$root_filesystem_target/boot"
    mount_partition "${user_options["$BOOT_PARTITION_KEY"]}" "$boot_target_tmp"

    fstab_write "$root_filesystem_target"

    log "$root_filesystem_target is ready for chroot"
}

tarball_download_unpack() {
    local root_target="$1"
    local boot_target="$2"
    # shellcheck disable=SC2034
    local tarball_file="$3"

    if findmnt --fstab "$root_target"; then
        abort "$root_target found in /etc/fstab"
    elif findmnt --fstab "$boot_target"; then
        abort "$boot_target found in /etc/fstab"
    fi

    tarball_download tarball_file "$4"
    tarball_unpack tarball_file "$root_target"

    log "Moving all files from $root_target/boot/* to $boot_target"
    sudo mv "$root_target"/boot/* "$boot_target"
    sync
}

tarball_unpack() {
    local -n data="$1"
    local target="$2"

    if [ ! -f "$data" ]; then
        abort "Tarball file $data not found."
    fi

    log "Untarring $data to $target"
    sudo bsdtar -xpf "$data" -C "$target"
    sync
}

# tarball_download()
tarball_download() {
    local -n out="$1"
    local -n tmp="$2"

    if [ "$out" != "download" ]; then
        log "Tarball provided by user, not downloading."
        return
    fi

    tmp="$(mktemp -d --suffix=-archlinuxarm_unpack.s)"
    tarball="ArchLinuxARM-rpi-aarch64-latest.tar.gz"
    out="$tmp/$tarball"
    wget -O "$out" "http://os.archlinuxarm.org/os/$tarball"
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

    # Provide line break for output readability
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

# TODO rename these following the tarball name convention
# declare -r BOOT_PARTITION_KEY="boot_partition"
declare -r BOOT_PARTITION_KEY="boot_partition"
# declare -r ROOT_PARTITION_KEY="root_partition"
declare -r ROOT_PARTITION_KEY="root_partition"
# declare -r USER_ENV_FILE_KEY="user_env_file"
declare -r USER_ENV_FILE_KEY="user_env_file"
# declare -r CONFIG_KEY_TARBALL="tarball_file_name"
declare -r CONFIG_KEY_TARBALL="tarball_file_name"

collect_user_options() {
    local -n config="$1"
    shift
    log "starting"

    optstring=":f:e:r:b:t:h"
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
            f)
                tarball_file_name="${OPTARG}"
                log "$tarball_file_name will be used for writing the root filesystem data."
                # optional
                config["$CONFIG_KEY_TARBALL"]="$tarball_file_name"
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

    # required
    config["$BOOT_PARTITION_KEY"]="${boot_partition:?"-b BOOT_PARTITION_KEY is required"}"
    config["$ROOT_PARTITION_KEY"]="${root_partition:?"-r ROOT_PARTITION_KEY is required"}"
    config["$USER_ENV_FILE_KEY"]="${user_env_file:?"-e USER_ENV_FILE_KEY"}"
}

declare -a TMP_DATA
trap "cleanup TMP_DATA" 1 2 3 6 EXIT

main "$@"
