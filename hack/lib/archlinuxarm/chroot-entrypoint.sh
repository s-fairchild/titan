#!/bin/bash

set -o nounset \
    -o errexit

DEBUG="${DEBUG:-"false"}"

if [ "$DEBUG" == "true" ]; then
    set -x
fi

main() {
    pacman_all
}

pacman_all() {
    pacman_keys
    pacman_update_pkgs

    pacman_install_pkgs_linux_rpi
    pacman_install_pkgs_bare_metal
}

pacman_remove_pkgs_bare_metal() {
    local -ar pkgs=(
        "linux-firmware"
        "uboot-raspberrypi"
        "firmware-raspberrypi"
    )
    pacman -Rs
}

pacman_keys() {
    pacman-key --init
    pacman-key --populate archlinuxarm
}

pacman_install_pkgs_bare_metal() {
    pacman -Sy --noconfirm

    local -ar pkgs=(
        "btrfs-progs"
        "python"
    )

    # shellcheck disable=SC2068
    pacman -S --noconfirm ${pkgs[@]}
}

pacman_install_pkgs_linux_rpi() {
    local -ar pkgs_linux_rpi=(
        "linux-rpi"
        "linux-rpi-headers"
    )
    local -ar pkgs_conflicts_conflicts=(
        "linux-aarch64"
        "uboot-raspberrypi"
    )

    # shellcheck disable=SC2068
    pacman -R ${pkgs_conflicts_conflicts[@]}
    # shellcheck disable=SC2068
    pacman -S ${pkgs_linux_rpi[@]}
}

pacman_update_pkgs() {
    pacman -Syu --noconfirm
}

pacman() {
    # shellcheck disable=SC2068
    command pacman --noconfirm $@
}

main
