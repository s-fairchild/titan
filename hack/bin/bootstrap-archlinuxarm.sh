#!/bin/bash

set -o nounset \
    -o errexit

DEBUG="${DEBUG:-"false"}"

if [ "$DEBUG" == "true" ]; then
    set -x
fi

main() {
    local -A user_options
    log "starting"

    collect_user_options user_options "$@"

    env_file="${user_options["$CONFIG_KEY_ENV_FILE"]}"
    if [ -f "$env_file" ]; then
        log "Sourcing $env_file..."
        # shellcheck source=../../docs/examples/archlinuxarm_subvolumes.env
        source "$env_file"
    fi

    # local -r root_mount_target="/mnt/root"
    local -r root_mount_target="/mnt/root"
    # local boot_mount_target="/mnt/boot"
    local boot_mount_target="/mnt/boot"

    log "Verifying all volume mounts."
    user_verify_mounts SUBVOLUME_MOUNT_ORDER \
                SUBVOLUMES \
                user_options \
                "$root_mount_target" \
                "$boot_mount_target"

    # btrfs_mount_options="defaults,noatime,autodefrag,compress=zstd:3,x-systemd.device-timeout=0"
    btrfs_mount_options="defaults,noatime,autodefrag,compress=zstd:3,x-systemd.device-timeout=0"
    mount_partition "${user_options["$CONFIG_KEY_ROOT_PARTITION"]}" \
                     "$root_mount_target" \
                     "$btrfs_mount_options"
                     

    log "Creating subvolumes."
    subvolumes_create SUBVOLUME_MOUNT_ORDER \
                      "$root_mount_target"
    
    log "Unmounting $root_mount_target"
    umount_partition "$root_mount_target"

    subvolumes_mount SUBVOLUMES \
                     SUBVOLUME_MOUNT_ORDER \
                     "${user_options["$CONFIG_KEY_ROOT_PARTITION"]}" \
                     "$root_mount_target" \
                     "$btrfs_mount_options"

    log "Mounting: ${user_options["$CONFIG_KEY_BOOT_PARTITION"]} $boot_mount_target"
    mount_partition "${user_options["$CONFIG_KEY_BOOT_PARTITION"]}" "$boot_mount_target"

    log "Unpacking root filesystem tarball."
    tarball_download_unpack "$root_mount_target" \
                            "$boot_mount_target" \
                            "${user_options["$CONFIG_KEY_TARBALL"]}" \
                            TMP_DATA

    log "Unmounting $boot_mount_target."
    umount_partition "$boot_mount_target"

    # local -r root_mount_target="/mnt/root"
    # local -r boot_mount_target="$root_mount_target/boot"
    local -r boot_mount_target="$root_mount_target/boot"
    mount_partition "${user_options["$CONFIG_KEY_BOOT_PARTITION"]}" "$boot_mount_target"

    log "Writing fstab to $root_mount_target"
    fstab_write "$root_mount_target"

    log "Writing cmdline.txt"
    # Requires rebuild of initramfs. This occurs after installing btrfs-progs in the chroot.
    cmdline_update "${user_options["$CONFIG_KEY_ROOT_PARTITION"]}" \
                   "$boot_mount_target" \
                   "${SUBVOLUME_MOUNT_ORDER[0]}"

    log "Chrooting into rootfs"
    chroot_container

    log "Writing config.txt"
    config_txt_write "$boot_mount_target"

    log "Copying ssh authorized_keys"
    copy_authorized_keys "${user_options["$CONFIG_KEY_SSH_PUBLIC_KEY"]}" "$root_mount_target"

    # local -r root_partition_dev="${user_options["$CONFIG_KEY_ROOT_PARTITION"]%%[0-9]}"
    local -r root_partition_dev="${user_options["$CONFIG_KEY_ROOT_PARTITION"]%%[0-9]}"

    if ! is_debug; then
        log "Unmounting $boot_mount_target, $root_mount_target"
        # Boot target must be unmounted before root target.
        # This is due to boot being mounted underneath root target.
        umount_partition "$boot_mount_target" "$root_mount_target"
        log "You can safely remove $root_partition_dev now."
    else
        log "All btrfs submodules are still mounted for debugging purposes"
        log "DO NOT remove without unmounting: $root_partition_dev now."
    fi
}

# declare -r file_check_err_suffix="not found. Are you in the repository root?"
declare -r file_check_err_suffix="not found. Are you in the repository root?"
# declare -r utils_lib="hack/lib/util.sh"
declare -r utils_lib="hack/lib/util.sh"
# declare -r bsdtar_lib="hack/lib/archlinuxarm/bsdtar.sh"
declare -r bsdtar_lib="hack/lib/archlinuxarm/bsdtar.sh"
# declare -r options_lib="hack/lib/archlinuxarm/options.sh"
declare -r options_lib="hack/lib/archlinuxarm/options.sh"
# declare -r verify_lib="hack/lib/archlinuxarm/verify.sh"
declare -r verify_lib="hack/lib/archlinuxarm/verify.sh"
# declare -r disks_lib="hack/lib/archlinuxarm/disks.sh"
declare -r disks_lib="hack/lib/archlinuxarm/disks.sh"
# declare -r arch_utils_lib="hack/lib/archlinuxarm/utils.sh"
declare -r arch_utils_lib="hack/lib/archlinuxarm/utils.sh"

[ -f "$utils_lib" ] || echo "$utils_lib $file_check_err_suffix" && exit 1
# shellcheck source=../lib/util.sh
source "$utils_lib"

[ -f "$bsdtar_lib" ] || abort "$bsdtar_lib $file_check_err_suffix"
# shellcheck source=../lib/archlinuxarm/bsdtar.sh
source "$bsdtar_lib"

[ -f "$options_lib" ] || abort "$options_lib $file_check_err_suffix"
# shellcheck source=../lib/archlinuxarm/options.sh
source "$options_lib"

[ -f "$verify_lib" ] || abort "$verify_lib $file_check_err_suffix"
# shellcheck source=../lib/archlinuxarm/verify.sh
source "$verify_lib"

[ -f "$disks_lib" ] || abort "$disks_lib $file_check_err_suffix"
# shellcheck source=../lib/archlinuxarm/utils.sh
source "$arch_utils_lib"

[ -f "$arch_utils_lib" ] || abort "$arch_utils_lib $file_check_err_suffix"
# shellcheck source=../lib/archlinuxarm/disks.sh
source "$disks_lib"

# shellcheck disable=SC2034
declare -a TMP_DATA
trap "cleanup TMP_DATA" 1 2 3 6 EXIT

main "$@"
