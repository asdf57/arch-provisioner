# arch-provisioner

Operator and provisioning image for the homelab. At startup it checks out the
configured `ansible-roles` revision from GitHub, so no source repository is
required on the host and playbook updates do not require rebuilding the image.
Init mode obtains the platform repositories as part of convergence. Normal
mode checks out only Ansible roles and fetches live inventory and SSH keys.

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
