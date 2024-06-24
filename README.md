# arch-provisioner
Spins up a [Lima](https://github.com/lima-vm/lima/) VM to build a custom Arch Linux ISO that supports Ansible provisioning.
# Building the ISO
To build the iso, first ensure that Lima is installed on your computer. Once installed, run `./buildiso.sh` in the root directory of this repository. This will build the Arch ISO and place it in an `out` directory at the root of this repository.

# Provisioning a machine
There are two ways to provision a machine. The first is to build a custom ISO using the steps above and deploy this ISO on the bare metal machine. The second is to the use the `livesetup.sh` script to prepare a live Arch environment using the default ISO for Ansible provisioning.

## Custom ISO

## Live Setup Script
In the live Arch environment, run

```
curl https://github.com/asdf57/arch-provisioner/blob/main/livesetup.sh | bash
```

to prepare the live environment for Ansible provisioning.
 
