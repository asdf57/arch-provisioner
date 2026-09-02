FROM alpine:3.24

ARG CONCOURSE_VERSION="7.12.1"

RUN apk add --no-cache \
    vim \
    bash \
    git \
    curl \
    jq \
    yq \
    python3 py3-pip py3-virtualenv \
    docker docker-compose \
    skopeo \
    openssh \
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

RUN apk add --no-cache --virtual .build-deps openbao

RUN curl -sL https://github.com/concourse/concourse/releases/download/v${CONCOURSE_VERSION}/fly-${CONCOURSE_VERSION}-linux-amd64.tgz -o /tmp/fly-linux-amd64.tgz && \
    tar -xvzf /tmp/fly-linux-amd64.tgz -C /usr/local/bin

WORKDIR /homelab

# Pre-create venv + sync Python deps
COPY pyproject.toml ./

RUN uv sync

RUN echo "%wheel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN adduser -u 1000 -D -s /bin/bash keiichi && \
    adduser keiichi wheel

# Copy rest of repo
COPY --chown=keiichi:keiichi ansible/filter_plugins/ ./ansible/filter_plugins/
COPY --chown=keiichi:keiichi profile.d/ /etc/profile.d/

RUN chown -R keiichi:keiichi /homelab

USER keiichi

ENV PATH="/homelab/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    ANSIBLE_INVENTORY="/homelab/inventory/inventory.yml" \
    ANSIBLE_ROLES_PATH="/homelab/ansible/roles" \
    ANSIBLE_FILTER_PLUGINS="/homelab/ansible/filter_plugins" \
    ANSIBLE_HOST_KEY_CHECKING=False

CMD ["/bin/bash"]
