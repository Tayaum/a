#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit
fi

# Ensure internet connectivity
ping -c 3 archlinux.org
if [ $? -ne 0 ]; then
  echo "No internet connectivity. Please check your network configuration."
  exit
fi

# Set variables
hostname="myarchvm"  # Replace with your desired hostname
username="tayaum"
password="tayaum"
timezone="Asia/Singapore"

# Partitioning the disk (assuming a single disk)
echo "Partitioning the disk..."
(
  echo o      # Clear existing partitions
  echo n      # New partition
  echo p      # Primary partition
  echo 1      # Partition number
  echo        # Default start sector
  echo +512M  # 512MB boot partition
  echo n      # New partition
  echo p      # Primary partition
  echo 2      # Partition number
  echo        # Default start sector
  echo        # Use the rest of the space for root
  echo a      # Mark the boot partition as active
  echo 1      # Select the first partition
  echo w      # Write changes
) | fdisk /dev/sda

# Format partitions
echo "Formatting partitions..."
mkfs.ext4 /dev/sda2
mkfs.ext4 /dev/sda1

# Mount root partition
echo "Mounting partitions..."
mount /dev/sda2 /mnt

# Install base system
echo "Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware vim networkmanager xorg xorg-xinit sudo

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the system
echo "Chrooting into the system..."
arch-chroot /mnt

# Set the time zone
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

# Localization
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Network configuration
echo "$hostname" > /etc/hostname
echo "127.0.0.1     localhost" >> /etc/hosts
echo "::1           localhost" >> /etc/hosts
echo "127.0.1.1     $hostname.localdomain  $hostname" >> /etc/hosts

# Set root password
echo "Setting root password..."
passwd

# Create a user and set password
useradd -m -G wheel -s /bin/bash "$username"
echo "$username:$password" | chpasswd

# Allow wheel group to use sudo
echo "%wheel ALL=(ALL) ALL" | (EDITOR="tee -a" visudo)

# Install and configure bootloader (GRUB)
echo "Installing and configuring GRUB..."
pacman -S grub
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# Enable NetworkManager service
systemctl enable NetworkManager

# Exit chroot
exit

# Unmount partitions and reboot
echo "Unmounting partitions..."
umount -R /mnt
reboot
