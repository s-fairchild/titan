#!/bin/bash

set -o nounset \
    -o errexit

main() {
    # shellcheck disable=SC2034
    local -r vm_name="rick-dev"
    local -r images="${HOME}/.local/share/libvirt/images"

    case "$1" in
        "create")
            local -r vm_env="hack/env/manage_dev_vm.env"
            if [ -f "$vm_env" ]; then
                # shellcheck source=env/manage_dev_vm.env
                source "$vm_env"
            else
                abort "VM Environment file $vm_env not found"
            fi

            # shellcheck disable=SC2034
            local -rA vm_settings=(
                ["name"]="$vm_name"
                ["image"]="${images}/fedora-coreos-39.20240407.3.0-qemu.x86_64.qcow2"
                ["ignition"]="${PWD}/$ignition_cluster_dev"
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

    vcpus="2"
    ram_mb="4096"
    disk_gb="30"
    raid_disk_gb="5"
    disk_serial1="raid10.1"
    disk_serial2="raid10.2"
    disk_serial3="raid10.3"
    disk_serial4="raid10.4"
    disk_serial5="raid5.1"
    disk_serial6="raid5.2"
    disk_serial7="raid5.3"
    disk_serial8="backups"
    stream="stable"

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

declare -r utils="hack/utils.sh"
if [ -f "$utils" ]; then
    # shellcheck source=utils.sh
    source "$utils"
fi

declare -r env_file="hack/env/manage_ignition.env"
if [ -f "$env_file" ]; then
    # shellcheck source=env/manage_ignition.env
    source "$env_file"
else
    abort "Missing $env_file, aborting"
fi

main "$@"
