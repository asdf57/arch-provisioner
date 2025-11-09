#!/usr/bin/env bash

set -x

cd /homelab

apk add --no-cache \
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
    cargo

apk add --update --virtual .deps --no-cache gnupg && \
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

rm -rf /var/cache/apk/*

adduser -u 1000 -D keiichi

echo 'keiichi ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/keiichi
chmod 0440 /etc/sudoers.d/keiichi

chown -R keiichi:keiichi /homelab /home/keiichi

uv venv .venv
uv sync
