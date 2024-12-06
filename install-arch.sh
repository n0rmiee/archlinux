#!/bin/bash

# Check for root permissions
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

echo "Welcome to the Complete Arch Linux Installation Script!"

# List available disks
echo "Available disks:"
lsblk -d -n -o NAME,SIZE,TYPE | grep "disk"

# Ask for the disk to install Arch Linux
echo "Enter the disk to install Arch Linux on (e.g., /dev/sda):"
read DISK

# List partitions on the selected disk
echo "Partitions on $DISK:"
lsblk "$DISK" -o NAME,SIZE,TYPE,MOUNTPOINT

# Ask user to select a partition to install Arch Linux
echo "Enter the partition on which to install Arch Linux (e.g., /dev/sda1):"
read PARTITION

# Ask if the user wants to create a swap file
echo "Do you want to create a swap file? (yes/no)"
read CREATE_SWAP

# Choose a desktop environment
echo "Choose a desktop environment to install:"
echo "1) GNOME"
echo "2) KDE Plasma"
echo "3) XFCE"
echo "4) Skip (no desktop environment)"
read DE_CHOICE

# Confirmation before proceeding
echo "You have selected the following options:"
echo "Disk: $DISK"
echo "Partition: $PARTITION"
echo "Swap file: $CREATE_SWAP"
echo "Desktop Environment: $DE_CHOICE"
echo "Proceed with installation? (yes/no)"
read PROCEED
if [ "$PROCEED" != "yes" ]; then
  echo "Operation cancelled. Exiting."
  exit
fi

# Begin Installation
echo "Formatting and setting up the disk..."

# Format the selected partition
echo "Formatting $PARTITION as ext4..."
mkfs.ext4 "$PARTITION"

# Mount the selected partition
mount "$PARTITION" /mnt
echo "Partition $PARTITION mounted to /mnt."

# Create swap if selected
if [ "$CREATE_SWAP" == "yes" ]; then
  echo "Creating a 2GB swap file..."
  fallocate -l 2G /mnt/swapfile
  chmod 600 /mnt/swapfile
  mkswap /mnt/swapfile
  swapon /mnt/swapfile
  echo "/swapfile none swap sw 0 0" >> /mnt/etc/fstab
  echo "Swap file created and activated."
fi

# Install essential packages
pacstrap /mnt base linux linux-firmware vim
echo "Base system installed."

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab
echo "fstab file generated."

# Chroot into the new system
echo "Entering the chroot environment..."
arch-chroot /mnt <<EOF

# Set timezone to Bangladesh/Dhaka
ln -sf /usr/share/zoneinfo/Asia/Dhaka /etc/localtime
hwclock --systohc

# Localization
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "Enter a hostname for your system:"
read HOSTNAME
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Set root password
echo "Set the root password:"
passwd

# Install bootloader
pacman -S grub efibootmgr --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
echo "Bootloader installed."

# Install desktop environment based on user choice
case $DE_CHOICE in
  1)
    echo "Installing GNOME and essentials..."
    pacman -S --noconfirm gnome gnome-extra gdm
    systemctl enable gdm
    ;;
  2)
    echo "Installing KDE Plasma and essentials..."
    pacman -S --noconfirm plasma kde-applications sddm
    systemctl enable sddm
    ;;
  3)
    echo "Installing XFCE and essentials..."
    pacman -S --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
    systemctl enable lightdm
    ;;
  4)
    echo "Skipping desktop environment installation."
    ;;
  *)
    echo "Invalid choice. Skipping desktop environment installation."
    ;;
esac

# Install additional essential software
echo "Installing additional essential software..."
pacman -S --noconfirm \
  networkmanager network-manager-applet \
  firefox vlc libreoffice-fresh \
  git base-devel \
  bluez bluez-utils \
  cups hplip \
  flatpak
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups

# Enable Flatpak repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
echo "Flatpak configured."

EOF

# Unmount partitions and reboot
umount -R /mnt
echo "Installation complete! Rebooting..."
reboot
