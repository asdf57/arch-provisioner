# Start with the official Nix Docker image
FROM nixos/nix:latest

# Enable flakes and nix-command
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Set up working directory
WORKDIR /workspace

# Copy only the flake files first (for better layer caching)
COPY flake.nix ./
COPY flake.lock* ./
COPY pyproject.toml ./
COPY scripts/build_setup.sh scripts/build_setup.sh

# Build the development environment
# This creates a layer with all dependencies cached
RUN nix --accept-flake-config develop --build \
    && nix run .#setup

COPY . .

RUN mkdir -p /home/nix/.ssh

RUN echo "source /workspace/scripts/runtime_setup.sh" >> /root/.bashrc

CMD ["nix", "--accept-flake-config", "develop", "--command", "bash"]