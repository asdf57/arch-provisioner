#!/bin/bash

# This script is run inside the Arch Linux VM to initialize it
# It is copied to the VM by the buildiso.sh script

set -eux -o pipefail

# Partition, format, and mount the vda disk
sudo parted /dev/vda --script mklabel gpt
sudo parted /dev/vda --script mkpart primary ext4 1MiB 100%
sudo mkfs.ext4 /dev/vda1
sudo mount /dev/vda1 /mnt

# Set up directories for overlay filesystem
sudo mkdir -p /mnt/upperdir
sudo mkdir -p /mnt/workdir

# Create overlay mount
sudo mount -t overlay overlay -o lowerdir=/,upperdir=/mnt/upperdir,workdir=/mnt/workdir /mnt

# Remove the existing resolv.conf file and copy the host's resolv.conf file to the new writable environment
sudo rm /mnt/etc/resolv.conf
sudo cp /etc/resolv.conf /mnt/etc/resolv.conf

# Mount the necessary filesystems for chroot
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys

# Chroot into the new environment
sudo chroot /mnt

# Initialize the pacman keyring
pacman-key --init

# Populate the Arch Linux keyring
pacman-key --populate

# Populate mirrorlist
cat <<EOF > /etc/pacman.d/mirrorlist
Server = https://plug-mirror.rcac.purdue.edu/archlinux/\$repo/os/\$arch
Server = https://mirror.csclub.uwaterloo.ca/archlinux/\$repo/os/\$arch
Server = https://mirror.theash.xyz/arch/\$repo/os/\$arch
Server = https://archlinux.uk.mirror.allworldit.com/archlinux/\$repo/os/\$arch
Server = https://mirror.jordanrey.me/archlinux/\$repo/os/\$arch
Server = https://mirror.pseudoform.org/\$repo/os/\$arch
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
