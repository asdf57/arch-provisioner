FROM alpine:3.22

RUN apk add --no-cache \
    bash \
    git \
    curl \
    jq \
    yq \
    python3 py3-pip py3-virtualenv \
    docker-cli docker-compose \
    openssh \
    shadow \
    coreutils \
    findutils \
    sudo \
    tar \
    build-base \
    uv \
    libffi-dev \
    openssl-dev \
    cargo \
    && rm -rf /var/cache/apk/*

RUN apk add --update --virtual .deps --no-cache gnupg && \
    cd /tmp && \
    wget https://releases.hashicorp.com/vault/1.20.4/vault_1.20.4_linux_amd64.zip && \
    wget https://releases.hashicorp.com/vault/1.20.4/vault_1.20.4_SHA256SUMS && \
    wget https://releases.hashicorp.com/vault/1.20.4/vault_1.20.4_SHA256SUMS.sig && \
    wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import && \
    gpg --verify vault_1.20.4_SHA256SUMS.sig vault_1.20.4_SHA256SUMS && \
    grep vault_1.20.4_linux_amd64.zip vault_1.20.4_SHA256SUMS | sha256sum -c && \
    unzip /tmp/vault_1.20.4_linux_amd64.zip -d /tmp && \
    mv /tmp/vault /usr/local/bin/vault && \
    rm -f /tmp/vault_1.20.4_linux_amd64.zip vault_1.20.4_SHA256SUMS 1.20.4/vault_1.20.4_SHA256SUMS.sig && \
    apk del .deps

WORKDIR /workspace

# Pre-create venv + sync Python deps
COPY pyproject.toml ./
RUN uv venv .venv && uv sync

RUN echo "%wheel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN useradd -G wheel -m -s /bin/bash keiichi
RUN passwd -d keiichi

# Copy rest of repo
COPY --chown=keiichi:keiichi . .
RUN chown -R keiichi:keiichi /workspace

USER keiichi

# Change the ownership

# Environment setup
ENV PATH="/workspace/.venv/bin:$PATH" \
    PYTHONPATH="/workspace/.venv/lib/python3.12/site-packages" \
    ANSIBLE_INVENTORY="/workspace/inventory/inventory.yml" \
    ANSIBLE_ROLES_PATH="/workspace/ansible/roles" \
    ANSIBLE_FILTER_PLUGINS="/workspace/ansible/filter_plugins" \
    ANSIBLE_HOST_KEY_CHECKING=False

RUN echo "source scripts/runtime_setup.sh" >> /home/keiichi/.bashrc

CMD ["/bin/bash"]
