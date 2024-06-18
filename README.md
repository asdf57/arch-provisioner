# arch-provisioner
Spins up a [Lima](https://github.com/lima-vm/lima/) VM to build a custom Arch Linux ISO that supports Ansible provisioning.
# Building the ISO
To build the iso, first ensure that Nix is installed on your system. Nix is required to build Lima, which is itself required to create the Arch VM. Once installed, run `./buildiso.sh` in the root directory of this repository.
