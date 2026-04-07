# arch-provisioner
A comprehensive homelab automation platform designed for automated provisioning and remote management of nodes.

## Getting Started

### Related Repos
- [prov2](https://github.com/asdf57/prov2)
- [inventory](https://github.com/asdf57/inventory)
- [hostvars](https://github.com/asdf57/hostvars)
- [commands_data](github.com/asdf57/commands_data)
- [ansible-roles](https://github.com/asdf57/ansible-roles)

### Prerequisites
- Docker
- `make` build tool
- Access to target infrastructure nodes

### Installation & Setup
1. **Create Shared Bootstrap Config**
   - Copy `.env.shared.example` to `.env.shared`
   - Fill in the secure shared values you want every infra node to use

2. **Initialize Infrastructure**
   ```bash
   make init-platform
   ```
   This single command now:
   - detects host-local values and writes `.env.local`
   - creates the `homelab` group and host data directory
   - generates missing SSH keys
   - renders `.env` from `.env.shared` and `.env.local`
   - Deploys the infrastructure compose cluster
     - Provisioning API
     - nginx file store
     - Vault
     - Concourse CI/CD
   - Builds and uploads netboot images for Debian and Arch Linux distros

3. **Deploy Configuration**
   ```bash
   hlcli upload <schema_file_path>
   ```
   Upload your schema file to the provisioning API to initialize a new node.

4. **Provision Servers**
   ```bash
   hlcli init servers
   ```
   or
   ```bash
   hlcli init server <server_name>
   ```
   Initialize server provisioning based on the uploaded configuration schema.

## Architecture

The platform operates through a containerized microservices architecture, supporting both bare metal and containerized development environments. The system provides automated netboot capabilities and a common homelab environment to manage nodes seamlessly.
