FROM alpine:3.22

ARG DOCKER_GID=999
ARG CONCOURSE_VERSION="7.12.1"

RUN apk add --no-cache \
    vim \
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

RUN curl -sL https://github.com/concourse/concourse/releases/download/v${CONCOURSE_VERSION}/fly-${CONCOURSE_VERSION}-linux-amd64.tgz -o /tmp/fly-linux-amd64.tgz && \
    tar -xvzf /tmp/fly-linux-amd64.tgz -C /usr/local/bin

WORKDIR /homelab

# Pre-create venv + sync Python deps
COPY pyproject.toml ./

RUN uv venv .venv && uv sync

RUN echo "%wheel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN addgroup -g ${DOCKER_GID} docker || true && \
    adduser -u 1000 -D keiichi && \
    adduser keiichi docker && \
    echo 'keiichi ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/keiichi && \
    chmod 0440 /etc/sudoers.d/keiichi

# Copy rest of repo
COPY --chown=keiichi:keiichi ansible/filter_plugins/ ./ansible/filter_plugins/
COPY --chown=keiichi:keiichi profile.d/ /etc/profile.d/
COPY --chown=keiichi:keiichi schemas/ ./schemas/
COPY --chown=keiichi:keiichi scripts/ ./scripts/

RUN chown -R keiichi:keiichi /homelab

USER keiichi

# Allow non-interactive shells to source .bashrc
ENV BASH_ENV="/home/keiichi/.bashrc"

ENV PATH="/homelab/.venv/bin:$PATH" \
    PYTHONPATH="/homelab/.venv/lib/python3.12/site-packages" \
    ANSIBLE_INVENTORY="/homelab/inventory/inventory.yml" \
    ANSIBLE_ROLES_PATH="/homelab/ansible/roles" \
    ANSIBLE_FILTER_PLUGINS="/homelab/ansible/filter_plugins" \
    ANSIBLE_HOST_KEY_CHECKING=False

RUN echo 'export PATH="/homelab/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' >> /home/keiichi/.profile

CMD ["/bin/bash"]
