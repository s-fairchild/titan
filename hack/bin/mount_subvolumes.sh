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

    subvolumes_mount SUBVOLUMES \
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

declare -r utils_lib="hack/lib/util.sh"
declare -r bsdtar_lib="hack/lib/archlinuxarm/bsdtar.sh"
declare -r options_lib="hack/lib/archlinuxarm/options.sh"
declare -r verify_lib="hack/lib/archlinuxarm/verify.sh"
declare -r btrfs_subvolumes_lib="hack/lib/archlinuxarm/btrfs-subvolumes.sh"
declare -r mount_lib="hack/lib/archlinuxarm/mount.sh"
declare -r arch_utils_lib="hack/lib/archlinuxarm/utils.sh"

if [ ! -f "$utils_lib" ]; then
    echo "$utils_lib not found. Are you in the repository root?"; exit 1
elif [ ! -f "$bsdtar_lib" ]; then
    abort "$bsdtar_lib not found. Are you in the repository root?"
elif [ ! -f "$options_lib" ]; then
    abort "$options_lib not found. Are you in the repository root?"
elif [ ! -f "$btrfs_subvolumes_lib" ]; then
    abort "$btrfs_subvolumes_lib not found. Are you in the repository root?"
elif [ ! -f "$mount_lib" ]; then
    abort "$mount_lib not found. Are you in the repository root?"
elif [ ! -f "$arch_utils_lib" ]; then
    abort "$arch_utils_lib not found. Are you in the repository root?"
fi

# shellcheck source=../lib/util.sh
source "$utils_lib"
# shellcheck source=../lib/archlinuxarm/bsdtar.sh
source "$bsdtar_lib"
# shellcheck source=../lib/archlinuxarm/options.sh
source "$options_lib"
# shellcheck source=../lib/archlinuxarm/verify.sh
source "$verify_lib"
# shellcheck source=../lib/archlinuxarm/btrfs-subvolumes.sh
source "$btrfs_subvolumes_lib"
# shellcheck source=../lib/archlinuxarm/utils.sh
source "$arch_utils_lib"

# shellcheck disable=SC2034
declare -a TMP_DATA
trap "cleanup TMP_DATA" 1 2 3 6 EXIT

main "$@"
