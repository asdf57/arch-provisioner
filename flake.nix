{
  description = "Homelab environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { 
          inherit system;
          config.allowUnfree = true;
        };
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
            nebula
            bash
            vim
            yq
            iputils
            vault
            fly
            sudo
          ];

          shellHook = ''
            export ANSIBLE_INVENTORY="$(pwd)/inventory/inventory.yml"
            export ANSIBLE_ROLES_PATH="$(pwd)/ansible/roles"
            export ANSIBLE_FILTER_PLUGINS="$(pwd)/ansible/filter_plugins:$ANSIBLE_FILTER_PLUGINS"
            export ANSIBLE_HOST_KEY_CHECKING=False

            uv sync
            source $(pwd)/.venv/bin/activate
          '';
        };
      }
    );
}
