#!/bin/bash

set -o nounset \
    -o errexit

main() {
    # shellcheck disable=SC2034
    local -r vm_name="rick-dev"
    local -r images="${HOME}/.local/share/libvirt/images"

    case "$1" in
        "create")
            # TODO set these variables in a better way
            # shellcheck disable=SC2034
            local -r image="${images}/fedora-coreos-39.20240407.3.0-qemu.x86_64.qcow2"
            # shellcheck disable=SC2034
            local -r ignition="${PWD}/$ignition_cluster_dev"

            create_vm image \
                      vm_name \
                      ignition
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
    local -n img="$1"
    local -n name="$2"
    local -n ign="$3"
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
                 --name="$name" \
                 --vcpus="${vcpus}" \
                 --memory="${ram_mb}" \
                 --os-variant="fedora-coreos-${stream}" \
                 --import \
                 --graphics=spice \
                 --disk="size=${disk_gb},backing_store=${img},serial=coreos-boot-disk,boot.order=1" \
                 --disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial1},boot.order=2" \
                 --disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial2},boot.order=2" \
                 --disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial3},boot.order=2" \
                 --disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial4},boot.order=2" \
                 --disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial5},boot.order=2" \
                 --disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial6},boot.order=2" \
                 --disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial7},boot.order=2" \
                 --disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial8},boot.order=2" \
                 --network network=default \
                 --noautoconsole \
                 --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${ign}"
}

declare -r utils="hack/utils.sh"
if [ -f "$utils" ]; then
    # shellcheck source=utils.sh
    source "$utils"
fi

declare -r butane_ignition_files="hack/butane_ignition_files.env"
if [ -f "$butane_ignition_files" ]; then
    # shellcheck source=../hack/butane_ignition_files.env
    source "$butane_ignition_files"
else
    abort "Missing $butane_ignition_files, aborting"
fi

main "$@"
