#!/bin/bash

set -o nounset \
    -o errexit

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

main() {
    local -r vm_name="$2"
    local -r ign_config="${3:-"deploy/.ignition/staging_main.ign"}"

    case "$1" in
        "create")
            declare -r env_file="hack/env/manage_staging_vm.env"
            if [ -f "$env_file" ]; then
                # shellcheck source=env/manage_staging_vm.env
                source "$env_file"
            else
                abort "Missing $env_file, aborting"
            fi

            local -r images="${HOME}/.local/share/libvirt/images"
            # shellcheck disable=SC2034
            local -rA vm_settings=(
                ["name"]="$vm_name"
                # TODO get the latest iso file from deploy/isos to use here
                ["image"]="${images}/fedora-coreos-41.20241109.3.0-qemu.x86_64.qcow2"
                ["ignition"]="${PWD}/$ign_config"
                ["vcpus"]="$VCPUS"
                ["os_disk_gb"]="$OS_DISK_GB"
                ["raid_disk_gb"]="$RAID_DISK_GB"
                ["ram_mb"]="$RAM_MB"
                ["stream"]="$STREAM"
            )

            create_vm vm_settings
            ;;
        "delete")
            delete_vm vm_name
            ;;
        *)
            abort "unknown option \"$1\""
            ;;
    esac
}

delete_vm() {
    local -n name="$1"
    log "starting"

	sudo virsh destroy \
               "$name"

	sudo virsh undefine \
               "$name" \
               --remove-all-storage
}

create_vm() {
    local -n settings="$1"
    log "starting"

    disk_serial1="${DISK_PREFIX_APPDATA}.raid10.1"
    disk_serial2="${DISK_PREFIX_APPDATA}.raid10.2"
    disk_serial3="${DISK_PREFIX_APPDATA}.raid10.3"
    disk_serial4="${DISK_PREFIX_APPDATA}.raid10.4"
    disk_serial5="${DISK_PREFIX_CCTV}.raid10.1"
    disk_serial6="${DISK_PREFIX_CCTV}.raid10.2"
    disk_serial7="${DISK_PREFIX_CCTV}.raid10.3"
    disk_serial8="${DISK_PREFIX_CCTV}.raid10.4"

    virt-install --connect="qemu:///system" \
                 --name="${settings["name"]}" \
                 --vcpus="${settings["vcpus"]}" \
                 --memory="${settings["ram_mb"]}" \
                 --os-variant="fedora-coreos-${settings["stream"]}" \
                 --import \
                 --graphics=spice \
                 --disk="size=${settings["os_disk_gb"]},backing_store=${settings["image"]},serial=coreos-boot-disk,boot.order=1" \
                 --disk="size=${settings["raid_disk_gb"]},format=qcow2,serial=${disk_serial1},boot.order=2" \
                 --disk="size=${settings["raid_disk_gb"]},format=qcow2,serial=${disk_serial2},boot.order=2" \
                 --disk="size=${settings["os_disk_gb"]},format=qcow2,serial=${disk_serial3},boot.order=2" \
                 --disk="size=${settings["os_disk_gb"]},format=qcow2,serial=${disk_serial4},boot.order=2" \
                 --disk="size=${settings["os_disk_gb"]},format=qcow2,serial=${disk_serial5},boot.order=2" \
                 --disk="size=${settings["os_disk_gb"]},format=qcow2,serial=${disk_serial6},boot.order=2" \
                 --disk="size=${settings["os_disk_gb"]},format=qcow2,serial=${disk_serial7},boot.order=2" \
                 --disk="size=${settings["os_disk_gb"]},format=qcow2,serial=${disk_serial8},boot.order=2" \
                 --network network=default \
                 --noautoconsole \
                 --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${settings["ignition"]}"
}

declare -r utils="hack/lib/util.sh"
if [ -f "$utils" ]; then
    # shellcheck source=lib/util.sh
    source "$utils"
fi

main "$@"
