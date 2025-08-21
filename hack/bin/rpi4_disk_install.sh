#!/bin/bash
# https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-raspberry-pi4/#_installing_fcos_and_booting_via_u_boot

set -o nounset \
    -o errexit

DEBUG="${DEBUG:-"false"}"
if [ "$DEBUG" == "true" ]; then
    set -x
fi

main () {
    coreos_download_exit "$1" "$STREAM"

    local -r error_fail_prefix="must be provided"
    local -r fcosdisk="${1?"Installation disk $error_fail_prefix"}"
    local -r ignition_config_file="${2?"Ignition config must be provided$error_fail_prefix"}"
    local -r fcos_image_file="${3?"FCOS image file $error_fail_prefix"}"

    local -r boot_files_dir="/tmp/RPi4boot"
    local -r boot_efi_files_dir="$boot_files_dir/boot/efi"
    mkdir -p "$boot_efi_files_dir"

    download_pkgs "$boot_files_dir" "$RELEASE"
    extract_rpms_mv_uboot "$boot_files_dir" "$boot_efi_files_dir"

    coreos_install "$ignition_config_file" \
                    "$fcos_image_file" \
                    "$fcosdisk"

    cp_boot_files "$fcosdisk"
}

# download_pkgs()
download_pkgs() {
    dnf download \
            --resolve \
            --releasever="$2" \
            --forcearch=aarch64 \
            --destdir="$1" \
            uboot-images-armv8 bcm283x-firmware bcm283x-overlays
}

# extract_rpms_mv_uboot()
extract_rpms_mv_uboot() {
    for rpm in "$1"/*rpm; do
        rpm2cpio "$rpm" | sudo cpio -idv -D /tmp/RPi4boot/
    done

    sudo mv "$1/usr/share/uboot/rpi_arm64/u-boot.bin" "$2/rpi-u-boot.bin"
}

# coreos_install()
coreos_install() {
    sudo coreos-installer install \
                            -a aarch64 \
                            -i "$1" \
                            --append-karg nomodeset \
                            -f "$2" \
                            "$3"
}

# coreos_download_exit()
coreos_download_exit() {
    # Ensure $1 is not a disk device file
    if [[ ! "$1" =~ "^/" ]] && [ "$1" == "download" ]; then
        echo "download option provided, downloading FCOS image..."
        coreos_install_download "$2"
        exit 0
    fi
}

# coreos_install_download()
coreos_install_download() {
    output_dir="$HOME/Downloads/"
    if coreos-installer download \
                        -p metal \
                        -a aarch64 \
                        -s "$1" \
                        -C "$output_dir"; then
        echo "Successfully downloaded FCOS install image to $output_dir"
    fi
}

cp_boot_files() {
    local -r fcos_efi_part="$(lsblk "$1" -J -oLABEL,PATH  | jq -r '.blockdevices[] | select(.label == "EFI-SYSTEM").path')"

    local -r fcos_efi_part_mount="/tmp/FCOSEFIpart"
    mkdir -p "$fcos_efi_part_mount"
    sudo mount "$fcos_efi_part" "$fcos_efi_part_mount"
    # rsync fails to chown ./
    sudo rsync -avh --ignore-existing /tmp/RPi4boot/boot/efi/ /tmp/FCOSEFIpart/ || echo "Check for errors above"
    sudo umount "$fcos_efi_part"
}

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

declare -r config="hack/env/rpi4_disk_install.env"
if [ -f "$config" ]; then
    # shellcheck source=env/rpi4_disk_install.env
    source "$config"
else
    echo "WARNING: Config Environment File $config not found!"
fi

main "$@"
