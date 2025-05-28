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
    pacman_install_pkgs
    # pacman_update_pkgs
}

pacman_keys() {
    pacman-key --init
    pacman-key --populate archlinuxarm
}

pacman_install_pkgs() {
    pacman -Sy --noconfirm

    if [ "$BOARD_MODEL" = "$RPI_MODEL_5" ]; then
        pacman_install_pkgs_rpi5
    fi

    local -ar pkgs=(
        btrfs-progs
        python
    )

    # shellcheck disable=SC2068
    pacman -S ${pkgs[@]}
}

pacman_update_pkgs() {
    pacman -Syu
}

pacman() {
    # shellcheck disable=SC2068
    command pacman --noconfirm $@
}

pacman_install_pkgs_rpi5() {
    local -ar pkgs_rpi5=(
        linux-rpi
        linux-rpi-headers
    )
    local -ar pkg_rpi5_conflicts=(
        linux-aarch64 
        uboot-raspberrypi
    )

    # shellcheck disable=SC2068
    pacman -R ${pkg_rpi5_conflicts[@]}
    # shellcheck disable=SC2068
    pacman -S ${pkgs_rpi5[@]}
}

main
