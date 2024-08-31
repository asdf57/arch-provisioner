FROM archlinux:latest

RUN pacman -Sy --noconfirm archlinux-keyring
RUN pacman-key --init && pacman-key --populate archlinux

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm archiso

WORKDIR /build

COPY ansible_provisioning_key.pub /root/.ssh/authorized_keys

RUN chmod 600 /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh

COPY build_arch_iso.sh /build/build_arch_iso.sh

RUN chmod +x /build/build_arch_iso.sh

ENTRYPOINT ["/bin/bash", "/build/build_arch_iso.sh"]