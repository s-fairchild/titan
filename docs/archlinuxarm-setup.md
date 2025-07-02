# Initial setup for ArchLinuxARM Nodes

## Raspberry Pis

### PreRequisites

Install required packages:
1. `qemu-user-static`
    * If you are using host with a different CPU architecture (i. e. x86_64), chroot can be accomplished with qemu
2. `bsdtar`  bsdtar to untar ArchLinuxArm image files
```bash
sudo dnf in qemu-user-static bsdtar
```

1. Configure bootloader EEPROM for NVMe boot
   1. Install `rpi-imager`
   2. Flash an sdcard with the EEPROM utility
   3. Boot your Raspberry Pi to the newly flashed sdcard
2. Configure your ArchLinuxARM NVMe device
    * Follow the appropriate installation guides at archlinuxarm.org
    * In my case, this is [Raspberry Pi 4](https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-4) for the Raspberry Pi 4 and 5
    * You can customize the partition layout, root filesystem as desired. Arch will boot without issue to a different filesystem (such as btrfs)
    * :warning: You will need a larger boot partition than 200M. `pacman` will fail to update packages due to limited space on `/boot`
      * Here is my filesystem usage post package updates: `/dev/sdd1      1022M  289M  734M  29% /mnt/root/boot`
3. Create and mount your filesystems
```bash
# Replace with your device
INSTALL_DISK=/dev/sdd

fdisk "$INSTALL_DISK"
sudo mkfs.vfat -n BOOT "${INSTALL_DISK}1"
sudo mkfs.btrfs -L root -O quota "${INSTALL_DISK}2"
mkdir /mnt/{root,boot}
sudo mount "${INSTALL_DISK}1" /mnt/boot
sudo mount "${INSTALL_DISK}2" /mnt/root
```
4. Download and Copy files
```bash
wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz
sudo bsdtar -xpf ArchLinuxARM-rpi-aarch64-latest.tar.gz -C /mnt/root
sudo sync

# You will see many errors to preserve ownership, this is expected as it's unsupported by FAT32 filesystems
sudo mv /mnt/root/boot/* /mnt/boot/
```

### Btrfs subvolume setup

Example fstab
```bash
# Static information about the filesystems.
# See fstab(5) for details.

# <file system> <dir> <type> <options> <dump> <pass>
UUID="$BOOT_UUID"  /boot   vfat    defaults        0       0

UUID="$ROOT_UUID" / btrfs defaults,noatime,autodefrag,compress=zstd,commit=120,subvol=root 0 0
UUID="$ROOT_UUID" /var btrfs defaults,noatime,autodefrag,compress=zstd,commit=120,subvol=var 0 0
UUID="$ROOT_UUID" /var btrfs defaults,noatime,autodefrag,compress=zstd,commit=120,subvol=var 0 0/var/lib/containers btrfs defaults,noatime,autodefrag,compress=zstd,commit=120,subvol=var_lib_containers 0 0
UUID="$ROOT_UUID" /var/cache/pacman/pkg btrfs defaults,noatime,autodefrag,compress=zstd,commit=120,subvol=var_cache_pacman_pkg 0 0
UUID="$ROOT_UUID" /root btrfs defaults,noatime,autodefrag,compress=zstd,commit=120,subvol=root_home 0 0
UUID="$ROOT_UUID" /home btrfs defaults,noatime,autodefrag,compress=zstd,commit=120,subvol=home 0 0
UUID="$ROOT_UUID" /usr/local btrfs defaults,noatime,autodefrag,compress=zstd,commit=120,subvol=usr_local 0 0
```

### Arch Linux ARM Pre Boot Setup

1. Chroot into the new root filesystem
    - Reference: [Chrooting into arm/arm64 environment from x86_64](https://wiki.archlinux.org/title/QEMU#Chrooting_into_arm/arm64_environment_from_x86_64)

```bash
# Mount the boot partition under the chroot environment
sudo sed -i 's/mmcblk0/mmcblk1/g' /mnt/root/etc/fstab
umount /mnt/boot
mount /dev/sdd1 /mnt/root/boot/

# Ensure that systemd-binfmt.service is running
systemctl status systemd-binfmt
# Restart if not
systemctl restart systemd-binfmt

# Using systemd-nspawn simplifies network setup, without the need to install arch-chroot
systemd-nspawn -D /mnt/root -M archlinuxarm --bind-ro=/etc/resolv.conf
```
2. Configure pacman and install packages
```bash
# Prepare pacman keys
pacman-key --init
pacman-key --populate archlinuxarm

# Update all packages
pacman -Syu

# Must be installed first to allow building the initramfs image for linux-rpi
pacman -S btrfs-progs

# linux-rpi is required to boot to the RPI5
# python is required to use ansible
pacman -S linux-rpi linux-rpi-headers python

# Optional, disable unused components
# Disable wifi
sed -i 's/#dtoverlay=disable-wifi/dtoverlay=disable-wifi/g' /boot/config.txt
# Disable bluetooth
sed -i 's/#dtoverlay=disable-bt/dtoverlay=disable-bt/g' /boot/config.txt

# Enable pre-OS debugging uart
echo -e '\nuart_2ndstage=1' >> boot/config.txt

# Enable OS uart
echo -e '\nenable_uart=1' >> boot/config.txt
```
3. Configure networking
```bash
# TODO configure static ip via systemd-networkd
```
