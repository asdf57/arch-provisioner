# arch-provisioner
A comprehensive homelab automation platform designed for automated provisioning and remote management of nodes.

## Getting Started

### Prerequisites
- Docker
- `make` build tool
- Access to target infrastructure nodes

### Installation & Setup
1. **Configure Schema**
   - Create a new schema file in the `schemas/` directory
   - Refer to the provisioning API documentation for complete schema specifications (available after API initialization)

2. **Initialize Default Configuration**
   - Populate the defaults file located in the `init` role with required configuration data
   - Ensure all mandatory fields are completed before proceeding

3. **Build Core Components**
   **Provisioning Service:**
   ```bash
   ./build_image.sh
   ```
   This builds the `prov` Docker image required for the homelab environment.

   **Command Line Interface:**
   ```bash
   cd cmd/
   make install
   ```
   This compiles and installs the `hlcli` tool to `~/.local/bin` for user access.

4. **Initialize Infrastructure**
   ```bash
   hlcli init infra
   ```
   - Deploys the infrastructure compose cluster
    - Provisioning API
    - nginx file store
    - Vault
    - Concourse CI/CD
   - Builds and uploads netboot images for Debian and Arch Linux distros

5. **Deploy Configuration**
   ```bash
   hlcli upload <schema_file_path>
   ```
   Upload your schema file to the provisioning API to initialize a new node.

6. **Provision Servers**
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
