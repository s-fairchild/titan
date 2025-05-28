#!/bin/bash

fstab_write() {
    local target="$1"
    log "starting"

    fstab="$(sudo genfstab -U "$target")"
    fstab="$(sed -e '/LABEL=zram0/ { N; d; }' <<< "$fstab")"
    etc="$target/etc"
    fstab_out="$etc/fstab"
    sudo mkdir -p "$etc"

    log "Writing fstab to $fstab_out"
    echo "$fstab" | sudo tee "$fstab_out" > /dev/null
}

cmdline_txt_get() {
    local -r f="$1"
    local -n out="$2"

    if check_file_exists "$f"; then
        # Remove trailing line break, or options appended will be after this new line
        mapfile -d ' ' -t out < <(cat $f | tr -d '\n')
    else
        out=(
            "root=/dev/mmcblk0p2"
            "rw"
            "rootwait"
            "console=serial0,115200"
            "console=tty1"
            "fsck.repair=yes"
        )
    fi
}

cmdline_update() {
    local -r root_part="$1"
    local -r boot_target="$2"
    local -r root_subvol="$3"
    log "starting"

    local -r cmdline_file_name="$boot_target/cmdline.txt"

    local -a cmdline
    cmdline_txt_get "$cmdline_file_name" cmdline

    eval "$(blkid -o export $root_part)"

    log "Updating $cmdline_file_name"
    for (( i=0; i < ${#cmdline[@]}; i++ )); do
        w="${cmdline[$i]}"
        if [[ $w =~ ^root=.* ]]; then
            new_root="root=PARTUUID=$PARTUUID"
            log "Found $w, replacing with $new_root."
            cmdline["$i"]="$new_root"
        fi
    done

    local -r type="btrfs"
    if [ "$TYPE" = "$type" ]; then
        log "Appending additional kernel cmdline options for $type..."
        cmdline+=("modules=$type")
        cmdline+=("rootflags=subvol=$root_subvol")
    fi
    # memory cgroup controller must be enabled by adding cgroup_enable=memory to /boot/cmdline.txt
    # https://archlinuxarm.org/forum/viewtopic.php?f=23&t=17131#p73138
    # https://github.com/raspberrypi/linux/pull/6524
    cmdline+=("cgroup_enable=memory")

    echo "New /boot/cmdline.txt: ${cmdline[*]}"
    echo "${cmdline[*]}" | sudo tee "$cmdline_file_name" > /dev/null
}

# config_txt_check()
# RPI4 with the default linux-rpi kernel does not have a config.txt provided
config_txt_check() {
    local -r f="$1"

    if ! check_file_exists "$f"; then
        echo "# For more options and information see:
# https://www.raspberrypi.com/documentation/computers/config_txt.html

# Some settings may impact device functionality. See link above for details

initramfs initramfs-linux.img followkernel

# Uncomment some or all of these to enable the optional hardware interfaces
#dtparam=i2c_arm=on
#dtparam=i2s=on
#dtparam=spi=on

# Additional overlays and parameters are documented
# /boot/overlays/README

# Automatically load overlays for detected cameras
camera_auto_detect=1

# Automatically load overlays for detected DSI displays
display_auto_detect=1

# Enable DRM VC4 V3D driver
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Don't have the firmware create an initial video= setting in cmdline.txt.
# Use the kernel's default instead.
disable_fw_kms_setup=1

# Disable compensation for displays with overscan
disable_overscan=1

# Uncomment if hdmi display is not detected and composite is being output
#hdmi_force_hotplug=1

# Uncomment if you want to disable wifi or bluetooth respectively
#dtoverlay=disable-wifi
#dtoverlay=disable-bt

# Uncomment this to enable infrared communication.
#dtoverlay=gpio-ir,gpio_pin=17
#dtoverlay=gpio-ir-tx,gpio_pin=18

# Run as fast as firmware / board allows
arm_boost=1

[rpi4]
# Enable host mode on the 2711 built-in XHCI USB controller.
# This line should be removed if the legacy DWC2 controller is required
# (e.g. for USB device mode) or if USB support is not required.
otg_mode=1

[rpi5]
dtoverlay=dwc2,dr_mode=host

[all]
" > "$f"
    fi

}

config_txt_update() {
    local -r boot_target="$1"
    log "starting"

    local -r config_txt="$boot_target/config.txt"
    config_txt_check "$config_txt"

    log "Disabling Wifi"
    sudo sed -i 's/#dtoverlay=disable-wifi/dtoverlay=disable-wifi/g' "$config_txt"

    log "Disabling Bluetooth"
    sudo sed -i 's/#dtoverlay=disable-bt/dtoverlay=disable-bt/g' "$config_txt"

    sudo sed -i 's/cm5/rpi5/' /mnt/root/boot/config.txt
    sudo sed -i 's/cm4/rpi4/' /mnt/root/boot/config.txt

    log "Enabling uart 1 and 2 (debug)"
    echo -e '\nuart_2ndstage=1\nenable_uart=1' | sudo tee -a "$config_txt" > /dev/null
}

chroot_container() {
    local -r board_model="$1"
    log "starting"

    container_name="archlinuxarm"
    entrypoint_host="$PWD/hack/lib/archlinuxarm/chroot-entrypoint.sh"
    entrypoint_container="/root/entrypoint.sh"
    log "Chrooting with systemd-nspawn container named: $container_name entrypoint script: $entrypoint_host"

    sudo systemd-nspawn -D /mnt/root \
                        -M "$container_name" \
                        --bind-ro=/etc/resolv.conf \
                        --bind-ro="$entrypoint_host:$entrypoint_container" \
                        bash -c "DEBUG=$DEBUG BOARD_MODEL=$board_model RPI_MODEL_5=$RPI_MODEL_5 $entrypoint_container"
}

copy_authorized_keys() {
    local -r pub_key="$1"
    local -r root_target="$2"
    log "starting"

    local -r root_ssh_dir="$root_target/root/.ssh"
    local -r alarm_ssh_dir="$root_target/home/alarm/.ssh"

    log "Creating ~/.ssh directories"
    sudo mkdir -v \
               -m 0700 \
               "$root_ssh_dir" \
               "$alarm_ssh_dir"

    local -r auth_keys="authorized_keys"
    log "Creating $auth_keys files"
    cat "$pub_key" | sudo tee "$root_ssh_dir/$auth_keys" > /dev/null
    cat "$pub_key" | sudo tee "$alarm_ssh_dir/$auth_keys" > /dev/null

    log "Setting permissions for $auth_keys files"
    sudo chmod 0600 "$root_ssh_dir/$auth_keys"
    sudo chmod 0600 "$alarm_ssh_dir/$auth_keys"
    sudo chown -R 1000:1000 "$alarm_ssh_dir"
}
