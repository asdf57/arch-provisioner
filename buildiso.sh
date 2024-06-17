#!/bin/bash

set -eux -o pipefail

run_in_chroot() {
  limactl shell arch-builder -- sudo chroot /mnt /bin/bash -c "$*"
}

if [ ! -d "out" ]; then
  echo "out directory doesn't exist, creating!"
  mkdir out
fi

# Check if nix is installed
if ! command -v nix-build &>/dev/null; then
    echo "Nix is not installed. Please install Nix and try again."
    exit 1
fi

# Install or skip Lima installation
if ! nix-env -q | grep lima; then
  echo "Building Lima package..."
  nix-build default.nix || { echo "Build failed"; exit 1; }
  echo "Installing the Lima package..."
  nix-env -i ./result || { echo "Installation failed"; exit 1; }
  echo "Lima installed successfully."
else
  echo "Lima already installed, skipping installation..."
fi

USER="$(whoami)"
LIMA_INSTANCE="arch-builder"
SSH_KEY_PATH="$HOME/.ssh/arch_provisioning_key"
VM_SSH_KEY_PATH="/home/$USER/.ssh/arch_provisioning_key"
ARCHLIVE_DIR="/home/$USER/archlive"
SCRIPT_DIR="$(pwd)"

# Step 1: Generate a public key for Ansible SSH operations between host and target
if [ ! -f "$SSH_KEY_PATH" ]; then
  ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N ""
fi

# Step 2: Create a temporary Lima Arch VM to build the Arch image
limactl delete -f $LIMA_INSTANCE || true
limactl create --name $LIMA_INSTANCE --tty=false arch.yaml
limactl start $LIMA_INSTANCE

# Initialize the VM
cat initvm.sh | limactl shell arch-builder -- sudo bash -s

# Step 3: Create .ssh directory and set proper permissions in VM
limactl shell $LIMA_INSTANCE -- sudo mkdir -p /mnt/home/$USER/.ssh
limactl shell $LIMA_INSTANCE -- sudo chown $USER:$USER /mnt/home/$USER/.ssh

# Step 4: Copy private and public keys to VM
limactl copy "$SSH_KEY_PATH" "${LIMA_INSTANCE}:/mnt/home/$USER/.ssh/"
limactl copy "$SSH_KEY_PATH.pub" "${LIMA_INSTANCE}:/mnt/home/$USER/.ssh/"

# Step 5: Set proper permissions for the copied keys
limactl shell $LIMA_INSTANCE -- sudo chown $USER:$USER /mnt/home/$USER/.ssh/arch_provisioning_key
limactl shell $LIMA_INSTANCE -- sudo chown $USER:$USER /mnt/home/$USER/.ssh/arch_provisioning_key.pub
limactl shell $LIMA_INSTANCE -- chmod 600 /mnt/home/$USER/.ssh/arch_provisioning_key
limactl shell $LIMA_INSTANCE -- chmod 644 /mnt/home/$USER/.ssh/arch_provisioning_key.pub

run_in_chroot pacman -S --noconfirm archiso

# Step 8: Set up workspace and build ISO
run_in_chroot mkdir -p /archiso/img
run_in_chroot cd /archiso/img
run_in_chroot cp -r /usr/share/archiso/configs/releng/ ./myarchiso

# Customize the ISO configuration as needed
# nano myarchiso/packages.x86_64

# Build the ISO
run_in_chroot "cd myarchiso && mkarchiso -v ."

limactl copy "${LIMA_INSTANCE}:/mnt/myarchiso/out/archlinux-*.iso" "out/"

# Step 4: Set up working directory for Arch ISO
# limactl shell $LIMA_INSTANCE mkdir -p $ARCHLIVE_DIR
# limactl shell $LIMA_INSTANCE sudo cp -r /usr/share/archiso/configs/releng/* $ARCHLIVE_DIR/
# # Use "tee -a" as way to append data to root-owned file without need for subshell
# limactl shell $LIMA_INSTANCE echo "openssh" | lima $LIMA_INSTANCE sudo tee -a $ARCHLIVE_DIR/packages.x86_64

# # Step 5: 
# limactl shell $LIMA_INSTANCE bash -c "cat <<EOF | sudo tee $ARCHLIVE_DIR/airootfs/root/startup.sh
# #!/bin/bash

# # Start SSH service
# systemctl start sshd

# # Wait for network to be up
# while ! ping -c 1 google.com &>/dev/null; do
#   sleep 1
# done

# # Add public key for SSH access
# mkdir -p /root/.ssh
# echo '$(cat $VM_SSH_KEY_PATH.pub)' > /root/.ssh/authorized_keys

# # Clear screen to ensure no runoff
# clear

# # Show block devices for provisioning
# lsblk

# # Print the IP address for the user
# ip addr show
# echo 'Arch ISO is ready for Ansible provisioning. Use this IP to connect.'
# EOF"
# lima $LIMA_INSTANCE sudo chmod +x $ARCHLIVE_DIR/airootfs/root/startup.sh

# # Step 6: Configure autostart
# lima $LIMA_INSTANCE sudo mkdir -p $ARCHLIVE_DIR/airootfs/etc/systemd/system/getty@tty1.service.d
# lima $LIMA_INSTANCE bash -c "cat <<EOF | sudo tee $ARCHLIVE_DIR/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf
# [Service]
# ExecStart=
# ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
# ExecStartPost=/usr/bin/bash /root/startup.sh
# EOF"


# # Step 7: Build the custom Arch ISO
# limactl shell $LIMA_INSTANCE sudo mkarchiso -v $ARCHLIVE_DIR

# # Step 8: Copy the generated ISO to host
# ISO_PATH=$(lima $LIMA_INSTANCE sudo find $ARCHLIVE_DIR/out -name "*.iso")
# limactl shell $LIMA_INSTANCE sudo chown root:root $ISO_PATH
# limactl copy $LIMA_INSTANCE:$ISO_PATH $SCRIPT_DIR/

# # Step 9: Clean up
# limactl stop $LIMA_INSTANCE
# limactl delete $LIMA_INSTANCE

# echo "Uninstalling lima"
# nix-env -q lima-0.22.0 || { echo "Uninstall failed"; exit 1; }
# echo "Lima uninstalled"
