FROM python:alpine3.19 AS builder

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
    vim

RUN pip3 install --upgrade pip
RUN pip3 install -r requirements.txt

ENV PATH="$PATH:/usr/local/bin"

# Create a new user with /bin/bash as the shell
RUN adduser -D -s /bin/bash condor

# Add the user to the root group for sudo-like privileges
RUN addgroup condor root

# Set up the working directory
WORKDIR /home/condor/provision

# Copy all private keys to the container
COPY * /home/condor/.ssh/

# COPY arch_provisioning_key /home/condor/.ssh/

COPY profile.d/* /etc/profile.d/

COPY scripts /usr/local/bin

# Copy necessary files
COPY ansible.cfg /etc/ansible/
COPY requirements.yml /home/condor/provision/
COPY schemas /home/condor/provision/schemas/
COPY server/schema.py /home/condor/provision/server/
COPY server/server.py /home/condor/provision/server/

COPY ansible /home/condor/provision/ansible/

COPY requirements.yml /home/condor/provision/ansible/

# Install Ansible Galaxy roles
RUN ansible-galaxy install -r /home/condor/provision/ansible/requirements.yml

# Set the entry point
ENTRYPOINT ["/bin/bash", "--login"]
