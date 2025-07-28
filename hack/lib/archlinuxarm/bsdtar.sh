#!/bin/bash

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

    if [ "$out" != "$BOOL_FALSE" ]; then
        log "Tarball provided by user, not downloading."
        return
    fi

    tmp="$(mktemp -d --suffix=-archlinuxarm_unpack.s)"
    tarball="ArchLinuxARM-rpi-aarch64-latest.tar.gz"
    out="$tmp/$tarball"
    wget -O "$out" "http://os.archlinuxarm.org/os/$tarball"
}
