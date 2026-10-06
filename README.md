# arch-provisioner

Operator and provisioning image for the homelab. At startup it checks out the
configured `ansible-roles` revision from GitHub, so no source repository is
required on the host and playbook updates do not require rebuilding the image.
Init mode obtains the platform repositories as part of convergence. Normal
mode checks out Ansible roles and resolves live inventory and verified public
Server host identities. Private runner credentials are supplied explicitly.

```sh
make build
```

No checkout is required on an operator host:

```sh
docker build -t homelab:latest \
  https://github.com/asdf57/arch-provisioner.git#main
```

Override `IMAGE_NAME` or `IMAGE_TAG` as needed. `GIT_ANSIBLE_ROLES_REPO` and
`GIT_ANSIBLE_ROLES_REF` select the runtime checkout. Use `homelabc init` to
initialize the platform and `homelabc run` to open an operator shell.
# Certificate-based management runner

Normal mode requires explicit runner credentials via `ANSIBLE_PRIVATE_KEY_FILE`,
`ANSIBLE_CERTIFICATE_FILE`, and
`STIGMERGY_API_TOKEN_FILE`, or the equivalent credential-valued environment
parameters for Concourse. It derives strict known_hosts from API-managed,
verified Server identities using Server-UID aliases. An explicit
`ANSIBLE_KNOWN_HOSTS_FILE` is optional for non-Server administrative inventories.
Missing credentials or unverified managed identities stop initialization.
The normal runner never retrieves per-server private keys or performs TOFU.

`CONTAINER_MODE=operator` initializes API and client SSH credentials but leaves
target inventory and host verification to the bounded external operator. The
host-key operator lives in ansible-roles/operators/ssh_host_keys.py, and must
construct scoped trust before running Ansible. Its Concourse pipeline supplies
a versioned Git input; it does not clone an unrelated latest checkout. The
generic image contains runtime dependencies, not host-specific key material.
