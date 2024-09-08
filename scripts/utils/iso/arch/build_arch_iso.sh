#!/bin/bash

set -euo pipefail

ISO_NAME="archlinux-$(date +%Y.%m.%d)-x86_64.iso"
OUTPUT_DIR="/output"
SSH_KEY_SOURCE="/root/.ssh/authorized_keys"
SSH_KEY_DEST="/archlive/releng/airootfs/root/.ssh/authorized_keys"

echo "- Creating output directory for the ISO at ${OUTPUT_DIR}"
mkdir -p ${OUTPUT_DIR}

echo "- Creating build directory for the Arch ISO at /archlive"
mkdir -p /archlive

echo "- Copying the default archiso profile to /archlive"
cp -r /usr/share/archiso/configs/releng/ /archlive

echo "- Adding openssh to the packages.x86_64 file (installs it in the live environment)"
echo "openssh" >> /archlive/releng/packages.x86_64

echo "- Creating the .ssh directory in the live environment for the root user"
mkdir -p /archlive/releng/airootfs/root/.ssh

echo "- Copying the provisioning SSH key to the live environment"
cp ${SSH_KEY_SOURCE} ${SSH_KEY_DEST}
chmod 600 ${SSH_KEY_DEST}
chmod 700 /archlive/releng/airootfs/root/.ssh

echo "- Adding disable for SSH password authentication and MaxAuthTries increase in the live environment"

echo "PasswordAuthentication no" >> \
    /archlive/releng/airootfs/etc/ssh/sshd_config
echo "MaxAuthTries 90" >> \
    /archlive/releng/airootfs/etc/ssh/sshd_config

echo "- Creating profile.d directory in the live environment"
mkdir -p /archlive/releng/airootfs/etc/profile.d

echo "- Creating a profile.d script to start the SSH daemon on login"
cat << 'EOF' > \
    /archlive/releng/airootfs/etc/profile.d/start_sshd.sh
#!/bin/bash
if ! systemctl is-active --quiet sshd; then
    systemctl start sshd
fi
EOF

# Make sure the script is executable
chmod +x /archlive/releng/airootfs/etc/profile.d/start_sshd.sh

# Enable DHCP for networking
ln -sf /usr/lib/systemd/system/dhcpcd.service \
    /archlive/releng/airootfs/etc/systemd/system/multi-user.target.wants/dhcpcd.service

# Navigate to the copied profile
cd /archlive/releng

# Build the Arch ISO
mkarchiso -v -o ${OUTPUT_DIR} .

# Move the ISO back to the host system's build directory

echo "- Arch Linux ISO build completed successfully."
echo "- ISO is available at ${OUTPUT_DIR}/${ISO_NAME}"
