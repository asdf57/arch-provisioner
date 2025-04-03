{
  description = "A Nix flake to install Python packages with uv and enter a bash shell with various tools";

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
            echo "Entering shell with necessary tools installed."
            if [ -f pyproject.toml ]; then
              echo "Installing Python dependencies from pyproject.toml using uv..."
              # Create a venv with uv and ensure Python installed in the PATH is used
              uv venv --python=python3 .venv
              
              # Install dependencies using uv directly
              if [ -f requirements.txt ]; then
                uv pip install -r requirements.txt --no-cache
              elif [ -f pyproject.toml ]; then
                uv pip install -e . --no-cache
              fi
              
              # Add the virtual environment bin directory to PATH
              export PATH="$(pwd)/.venv/bin:$PATH"
              
              echo "Python dependencies installed. The virtual environment is already activated."
            fi
          '';
        };
      }
    );
}