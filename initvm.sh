#!/bin/bash
# Boot into the Arch Linux live environment

set -eux -o pipefail

# Step 1: Partition, format, and mount the vda disk
## Create the GPT partition table
sudo parted /dev/vda --script mklabel gpt
## Create a single partition using the entire disk
sudo parted /dev/vda --script mkpart primary ext4 1MiB 100%
## Format the partition as ext4 filesystem
sudo mkfs.ext4 /dev/vda1
## Mount the partition to /mnt
sudo mount /dev/vda1 /mnt

# Step 2: Set up directories for overlay filesystem
## Create upperdir directory for writable layer
## Create workdir directory for work directory
sudo mkdir -p /mnt/upperdir
sudo mkdir -p /mnt/workdir

# Step 4: Create overlay mount
## Mount the overlay filesystem
### -t: filesystem type
### -o: mount options
### lowerdir: read-only layer
### upperdir: writable layer
### workdir: work directory (used by overlayfs to store internal data)
sudo mount -t overlay overlay -o lowerdir=/,upperdir=/mnt/upperdir,workdir=/mnt/workdir /mnt

sudo rm /mnt/etc/resolv.conf
sudo cp /etc/resolv.conf /mnt/etc/resolv.conf

# Step 6: Chroot into the new writable environment
## Bind mount /dev, /proc, and /sys to the new overlay filesystem
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo chroot /mnt

# Initialize the pacman keyring
pacman-key --init

# Populate the Arch Linux keyring
pacman-key --populate

# Step 7: Populate mirrorlist
cat <<EOF > /etc/pacman.d/mirrorlist
Server = http://mirrors.acm.wpi.edu/archlinux/\$repo/os/\$arch
Server = http://mirror.adectra.com/archlinux/\$repo/os/\$arch
Server = https://mirror.adectra.com/archlinux/\$repo/os/\$arch
Server = http://mirrors.advancedhosters.com/archlinux/\$repo/os/\$arch
Server = http://mirrors.aggregate.org/archlinux/\$repo/os/\$arch
Server = http://il.us.mirror.archlinux-br.org/\$repo/os/\$arch
Server = http://mirror.arizona.edu/archlinux/\$repo/os/\$arch
Server = https://mirror.arizona.edu/archlinux/\$repo/os/\$arch
Server = http://arlm.tyzoid.com/\$repo/os/\$arch
Server = https://arlm.tyzoid.com/\$repo/os/\$arch
Server = https://mirror.ava.dev/archlinux/\$repo/os/\$arch
Server = http://mirrors.bjg.at/arch/\$repo/os/\$arch
Server = https://mirrors.bjg.at/arch/\$repo/os/\$arch
Server = http://mirrors.bloomu.edu/archlinux/\$repo/os/\$arch
Server = https://mirrors.bloomu.edu/archlinux/\$repo/os/\$arch
Server = http://ca.us.mirror.archlinux-br.org/\$repo/os/\$arch
Server = http://mirrors.cat.pdx.edu/archlinux/\$repo/os/\$arch
Server = http://mirror.cc.columbia.edu/pub/linux/archlinux/\$repo/os/\$arch
Server = http://us.mirrors.cicku.me/archlinux/\$repo/os/\$arch
Server = https://us.mirrors.cicku.me/archlinux/\$repo/os/\$arch
Server = http://mirror.clarkson.edu/archlinux/\$repo/os/\$arch
Server = https://mirror.clarkson.edu/archlinux/\$repo/os/\$arch
Server = http://mirror.colonelhosting.com/archlinux/\$repo/os/\$arch
Server = https://mirror.colonelhosting.com/archlinux/\$repo/os/\$arch
Server = http://arch.mirror.constant.com/\$repo/os/\$arch
Server = https://arch.mirror.constant.com/\$repo/os/\$arch
Server = http://mirror.cs.pitt.edu/archlinux/\$repo/os/\$arch
Server = http://mirrors.kernel.org/archlinux/\$repo/os/\$arch
Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch
EOF

# Update the package database
pacman -Syu --noconfirm
