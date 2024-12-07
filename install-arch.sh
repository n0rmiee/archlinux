#!/bin/bash

set -e

# List all available disks (excluding partitions)
echo "Detecting available disks..."
DISKS=$(lsblk -d -p -n -l | grep -E 'disk' | awk '{print $1}')
echo "Available disks:"
echo "$DISKS"

# Prompt user to select a disk
read -p "Enter the disk you want to use (e.g., /dev/sda): " DISK

# Check if the disk exists
if [ ! -b "$DISK" ]; then
    echo "Error: Disk $DISK not found. Exiting."
    exit 1
fi

echo "Selected disk: $DISK"

# Set variables
HOSTNAME="archlinux"
USERNAME="user"
PASSWORD="password"
DESKTOP_ENV="xfce"  # Change to your preferred desktop environment (gnome, kde, etc.)

echo "Starting Arch Linux installation..."

# Launch cfdisk for manual partitioning
echo "Launching cfdisk for manual partitioning on $DISK..."
cfdisk $DISK

echo "Please ensure you've created the following partitions:"
echo "1. EFI partition (type: EFI System, size: 512 MiB)"
echo "2. Root partition (type: Linux filesystem, remaining space)"
read -p "Press Enter to continue after partitioning..."

# Verify partitions
lsblk $DISK
read -p "Are the partitions correct? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Exiting. Please re-run the script after correcting the partitions."
    exit 1
fi

# Get partition names (automatically detects partitions)
EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"

# Check if partitions exist
if [ ! -b "$EFI_PART" ] || [ ! -b "$ROOT_PART" ]; then
    echo "Error: One or both partitions do not exist. Please check your partitioning."
    exit 1
fi

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 "$ROOT_PART"

# Mount partitions
echo "Mounting partitions..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# Install base system and essential packages
echo "Installing base system and necessary packages..."
pacstrap /mnt base linux linux-firmware vim grub efibootmgr networkmanager \
         sudo git wget curl base-devel zsh htop neofetch ntp man-db \
         bash-completion iproute2 linux-headers netctl pciutils \
         xorg-server xorg-apps xfce4 xfce4-goodies lightdm lightdm-gtk-greeter \
         pulseaudio pulseaudio-alsa pavucontrol networkmanager-dmenu \
         firefox xf86-video-intel mesa intel-ucode \
         intel-media-driver libva-intel-driver

# Check if pacstrap was successful
if [ $? -ne 0 ]; then
    echo "Error: pacstrap failed. Please check the installation log."
    exit 1
fi

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Check if fstab was generated successfully
if [ $? -ne 0 ]; then
    echo "Error: Failed to generate fstab. Please check the system log."
    exit 1
fi

# Configure the system
echo "Configuring the system..."
arch-chroot /mnt bash -c "
    # Set timezone
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    hwclock --systohc

    # Set localization
    echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
    locale-gen
    echo 'LANG=en_US.UTF-8' > /etc/locale.conf

    # Set hostname
    echo '$HOSTNAME' > /etc/hostname
    echo '127.0.0.1   localhost' >> /etc/hosts
    echo '::1         localhost' >> /etc/hosts
    echo '127.0.1.1   $HOSTNAME.localdomain $HOSTNAME' >> /etc/hosts

    # Set root password
    echo 'root:$PASSWORD' | chpasswd

    # Add user
    useradd -m -G wheel $USERNAME
    echo '$USERNAME:$PASSWORD' | chpasswd
    echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel

    # Enable necessary services
    systemctl enable NetworkManager
    systemctl enable lightdm

    # Install bootloader (GRUB)
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    # Enable display manager (LightDM)
    systemctl enable lightdm
"

# Check if GRUB was successfully installed
if [ $? -ne 0 ]; then
    echo "Error: GRUB installation failed. Please check the system log."
    exit 1
fi

# Unmount and reboot
echo "Installation complete! Unmounting and rebooting..."
umount -R /mnt
reboot
