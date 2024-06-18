#!/bin/bash

set -eux -o pipefail

# Function to run a command in the chroot
run_in_chroot() {
  limactl shell arch-builder -- sudo chroot /mnt /bin/bash -c "$*"
}

# Check if out directory exists, if not create it
if [ ! -d "out" ]; then
  echo "out directory doesn't exist, creating!"
  mkdir out
fi

# Check if nix is installed, if not exit
if ! command -v limactl &>/dev/null; then
    echo "Lima is not installed. Please install Lima and try again."
    exit 1
fi

USER="$(whoami)"
LIMA_INSTANCE="arch-builder"
SSH_KEY_PATH="$HOME/.ssh/arch_provisioning_key"
ARCHLIVE_DIR="/home/$USER/archlive"
SCRIPT_DIR="$(pwd)"
VM_ARCHISO_DIR="/mnt/archiso"
VM_SSH_KEY_PATH="/mnt/home/$USER/.ssh"

# Generate a public key for Ansible SSH operations between host and target
if [ ! -f "$SSH_KEY_PATH" ]; then
  ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N ""
fi

# Create a temporary Lima Arch VM to build the Arch image, removing any existing VM
limactl delete -f $LIMA_INSTANCE || true
limactl create --name $LIMA_INSTANCE --tty=false arch.yaml
limactl start $LIMA_INSTANCE

# Initialize the VM
cat initvm.sh | limactl shell arch-builder -- sudo bash -s

# Create .ssh directory and set proper permissions in VM
limactl shell $LIMA_INSTANCE -- sudo mkdir -p ${VM_SSH_KEY_PATH}
limactl shell $LIMA_INSTANCE -- sudo chown $USER:$USER ${VM_SSH_KEY_PATH}

# Copy private and public keys to VM
# limactl copy "$SSH_KEY_PATH" "${LIMA_INSTANCE}:${VM_SSH_KEY_PATH}"
limactl copy "$SSH_KEY_PATH.pub" "${LIMA_INSTANCE}:${VM_SSH_KEY_PATH}"

# Set proper permissions for the copied keys
# limactl shell $LIMA_INSTANCE -- chmod 600 /mnt/home/$USER/.ssh/arch_provisioning_key
limactl shell $LIMA_INSTANCE -- chmod 644 /mnt/home/$USER/.ssh/arch_provisioning_key.pub

# Install packages in the VM's chroot environment
run_in_chroot pacman -S --noconfirm archiso openssh

# Set up workspace for building the Arch ISO
limactl shell $LIMA_INSTANCE -- sudo mkdir -p ${VM_ARCHISO_DIR}
limactl shell $LIMA_INSTANCE -- sudo cp -r /mnt/usr/share/archiso/configs/releng/ ${VM_ARCHISO_DIR}

# Add openssh to the packages list for the Arch ISO
limactl shell $LIMA_INSTANCE -- sudo bash -c "echo 'openssh' >> ${VM_ARCHISO_DIR}/releng/packages.x86_64"
run_in_chroot cat /archiso/releng/packages.x86_64

# Add startup script to enable SSH and add public key for Ansible in live environment
run_in_chroot bash -c "cat > /archiso/releng/airootfs/root/startup.sh << 'EOF'
#!/bin/bash

# Start SSH service
systemctl start sshd

# Wait for network to be up
while ! ping -c 1 google.com &>/dev/null; do
  sleep 1
done

# Add public key for SSH access
mkdir -p /root/.ssh
echo \$(cat /home/\$USER/.ssh/arch_provisioning_key.pub) > /root/.ssh/authorized_keys

# Clear screen to ensure no runoff
clear

# Show block devices for provisioning
lsblk

# Print the IP address for the user
echo 'Arch ISO is ready for Ansible provisioning. Use this IP to connect.'
EOF"

limactl shell $LIMA_INSTANCE -- cat ${VM_ARCHISO_DIR}/releng/airootfs/root/startup.sh
limactl shell $LIMA_INSTANCE -- sudo chmod +x ${VM_ARCHISO_DIR}/releng/airootfs/root/startup.sh

# Step 6: Configure autostart
limactl shell $LIMA_INSTANCE -- mkdir -p ${VM_ARCHISO_DIR}/releng/airootfs/etc/systemd/system/getty@tty1.service.d
run_in_chroot bash -c "cat > /archiso/releng/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
ExecStartPost=/usr/bin/bash /root/startup.sh
EOF"

# Build the custom Arch ISO
run_in_chroot "cd /archiso/releng/ && mkarchiso -v ."

# Copy the built ISO to host
limactl copy "${LIMA_INSTANCE}:${VM_ARCHISO_DIR}/releng/out/archlinux-*.iso" "out/"

# Clean up VM resources
limactl stop $LIMA_INSTANCE
limactl delete $LIMA_INSTANCE
