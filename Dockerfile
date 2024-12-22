FROM python:3.12.7-alpine3.20 AS builder

COPY requirements.txt .

# Install necessary packages
RUN apk add --no-cache \
    bash \
    curl \
    git \
    gcc \
    musl-dev \
    libffi-dev \
    openssl-dev \
    openssh-client \
    make \
    rsync \
    shadow \
    sudo \
    cargo \
    ansible \
    vim \
    yq \
    kubectl \
    helm

RUN pip3 install --upgrade pip
RUN pip3 install --prefix=/usr/local --no-warn-script-location -r requirements.txt

ENV PATH="$PATH:/usr/local/bin"

# Create a new user with /bin/bash as the shell
RUN adduser -D -s /bin/bash condor

# Add the user to the root group for sudo-like privileges
RUN addgroup condor root

RUN echo 'condor ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/condor

# Set up the working directory
WORKDIR /home/condor/provision

# Copy all private keys to the container
COPY hss/ssh_keys/* /home/condor/.ssh/
COPY hss/ssh_config/config /home/condor/.ssh/config

# Set proper permissions and ownership for SSH keys and config
RUN touch /home/condor/.ssh/known_hosts
RUN chmod 700 /home/condor/.ssh
RUN chmod 600 /home/condor/.ssh/known_hosts
RUN chown -R condor:condor /home/condor/.ssh

# Copy profile.d scripts
COPY profile.d/* /etc/profile.d/

# Copy necessary scripts and files
COPY scripts /usr/local/bin
COPY ansible.cfg /etc/ansible/
COPY requirements.yml /home/condor/provision/
COPY schemas /home/condor/provision/schemas/
COPY ansible /home/condor/provision/ansible/

# Set proper ownership for the provision directory
RUN chown -R condor:condor /home/condor/provision

# Install Ansible Galaxy roles
RUN ansible-galaxy install -r /home/condor/provision/requirements.yml

# Switch to non-root user
USER condor

# Set the entry point
ENTRYPOINT ["/bin/bash", "--login"]
