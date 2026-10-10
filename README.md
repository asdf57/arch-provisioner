# arch-provisioner

Operator and provisioning image for the homelab. At startup it checks out the
configured `ansible-roles` revision from GitHub, so no source repository is
required on the host and playbook updates do not require rebuilding the image.
Init mode obtains the platform repositories as part of convergence. Normal
mode checks out Ansible roles and resolves live inventory and verified public
Server host identities. Normal mode fetches existing runner credentials using the API token.

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

Normal mode requires only `STIGMERGY_API_TOKEN_FILE` (or `STIGMERGY_API_TOKEN`).
At startup it reads `SSHKeyPair/ansible-runner`, its UID-qualified owned Secret,
and `SSHCertificate/ansible-runner` from the API. It fetches the existing identity;
it never creates, signs or rotates keys. It verifies resource readiness, ownership,
validity and private/public/certificate subject agreement before writing files
under `/home/keiichi/.ssh` (0700 directory, 0600 files). Credentials live only in
the disposable container. Start a fresh shell to fetch a renewed certificate;
there is no background renewal within a running shell.

The token must permit GET of these resources and their referenced Secret;
ordinary runner/operator tokens do not gain Secret access automatically. An admin
token works with the current policy. Do not broaden fleet operator permissions
just to support interactive shells. Initialization refuses auth failures or stale,
invalid or mismatched credentials. It derives strict known_hosts from API-managed,
verified Server identities using Server-UID aliases. An explicit
`ANSIBLE_KNOWN_HOSTS_FILE` is optional for non-Server administrative inventories.
Missing credentials or unverified managed identities stop initialization.
The normal runner never retrieves per-server private keys or performs TOFU.

Normal mode also generates `/home/keiichi/.ssh/config` from resolved inventory,
including inherited host variables. Run `ssh beelink` (or any captured inventory
host name) directly: the configuration selects its address, user, port, runner
certificate and verified Server-UID host-key alias. No `/etc/hosts` modification
or shell wrapper is needed. Start a fresh container to refresh inventory and
credentials. This disposable container owns the generated SSH configuration;
unsupported inventory SSH options fail initialization rather than being ignored.

`CONTAINER_MODE=operator` takes explicit client credentials via
`ANSIBLE_PRIVATE_KEY_FILE`/`ANSIBLE_CERTIFICATE_FILE` or their credential-valued
environment counterparts supplied by Concourse/OpenBao. It does not fetch API
Secrets and leaves
target inventory and host verification to the bounded external operator. The
host-key operator lives in ansible-roles/operators/ssh_host_keys.py, and must
construct scoped trust before running Ansible. Its Concourse pipeline supplies
a versioned Git input; it does not clone an unrelated latest checkout. The
generic image contains runtime dependencies, not host-specific key material.

Ansible uses the standard callback with skipped tasks hidden and YAML results.
Executed tasks, failures, warnings and recaps remain visible. Fact injection is
disabled: plays use `ansible_facts`. Automated SSH runs without a pseudo-terminal
so terminal context sequences cannot contaminate module JSON. External operators
also set these options directly, so their logging fixes do not require an image
rebuild; the image configuration covers ordinary Command playbook invocations.
