{
  description = "Homelab environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      with pkgs;
      {
        devShells.default = mkShell {
          packages = [
            ansible
            ansible-lint
            docker
            docker-compose
            bmake
            diffutils
            dyff
            git
            go
            gotestsum
            iproute2
            jq
            k9s
            kanidm
            kube3d
            kubectl
            kubernetes-helm
            kustomize
            libisoburn
            neovim
            openssh
            opentofu
            p7zip
            pre-commit
            qrencode
            shellcheck
            wireguard-tools
            yamllint
            virtualenv
            uv
            python312
          ];

          shellHook = ''
            uv sync
            export PYTHONPATH="$(pwd)/.venv/lib/python3.12/site-packages"
            export PATH="$(pwd)/.venv/bin:$PATH"
            export VENV_PYTHON="$(which python3.12)"

            git clone git@github.com:asdf57/inventory.git inventory
            git clone git@github.com:asdf57/hostvar_data.git data/hostvar_data
            git clone git@github.com:asdf57/templates.git templates

            # Template the hostvars
            mkdir -p inventory/host_vars

            for host in $(ansible-inventory -i inventory/inventory.yml --list |jq -r '._meta.hostvars | keys[]'); do
              echo "=> Generating hostvars for $host"
              # Template the hostvars_data/<node>.yml and templates/hostvars.yml.j2 files
              jinja2 templates/hostvars.yml.j2 data/hostvar_data/$host.yml > inventory/host_vars/$host.yml
            done

            export ANSIBLE_INVENTORY="$(pwd)/inventory"
            export ANSIBLE_ROLES_PATH="$(pwd)/ansible/roles"
            export ANSIBLE_FILTER_PLUGINS="$(pwd)/ansible/filter_plugins:$ANSIBLE_FILTER_PLUGINS"
            export ANSIBLE_PRIVATE_KEY_FILE=/home/$(whoami)/.ssh/provisioning_key
            export ANSIBLE_HOST_KEY_CHECKING=False

            export PS1="homelab \$ "

            trap 'rm -rf inventory data templates .venv' EXIT
          '';
        };
      }
    );
}