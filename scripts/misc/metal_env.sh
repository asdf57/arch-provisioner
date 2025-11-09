#!/usr/bin/env bash

trap cleanup EXIT INT

repo_path=$(realpath .)
chroot_dir=$HOME/homelab_chroot
upper_dir=$HOME/homelab_upper
work_dir=$HOME/homelab_work
alpine_fs="alpine-minirootfs-3.22.0-x86_64"

overlay_root="$chroot_dir/homelab"
alpine_fs_file="$alpine_fs.tar.gz"

should_elevate=1
should_persist=1
should_cleanup=0

git_key_path="$HOME/.ssh/git_provisioning_key"

help() {
    echo "Usage: $0 [-e] [command]"
    echo "  -e    Run with root privileges (requires sudo)"
    echo "  -p    Persist the environment after exit"
    echo "  -c    Cleanup only (optionally may include -e but no other flags or commands)"
    echo "  -g    Provide a path (on host fs) to the private git ssh key"
}

cleanup(){
    if [[ $should_cleanup -eq 1 ]]; then
        echo ":: Persistence requested, skipping cleanup!"
        return
    fi

    echo ":: Running nix env cleanup..."

    if [[ $should_elevate -eq 0 ]]; then
        for dir in dev proc sys run; do
            umount -lf "$chroot_dir/$dir"
        done

        umount -lf "$overlay_root"
        rm -rf "$chroot_dir"
        rm -rf "$upper_dir"
        rm -rf "$work_dir"
    fi

    rm -f alpine-minirootfs-3.22.0-x86_64.tar.gz
    rm -rf rootfs/
    rm -rf inventory/
}

extract_alpine_rootfs() {
    local extract_dir
    extract_dir="$1"

    if [[ -f "$extract_dir/$alpine_fs_file" ]]; then
        echo ":: Alpine rootfs already exists, skipping download"
        return
    fi

    echo ":: Pulling Alpine Linux rootfs"
    wget https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/$alpine_fs_file > /dev/null 2>&1

    echo ":: Extracting rootfs"
    tar -xzf $alpine_fs.tar.gz -C "$extract_dir" > /dev/null 2>&1

    echo ":: Removing Alpine tarball"
    rm -f $alpine_fs.tar.gz
}

create_elevated_rootfs() {
    mkdir -p $chroot_dir $overlay_root $upper_dir $work_dir

    extract_alpine_rootfs "$chroot_dir"

    # Check if overlay already exists
    if mountpoint -q "$overlay_root"; then
        echo ":: Overlay mount already exists"
    else
        echo ":: Setting up overlay filesystem"
        mount -t overlay overlay -o lowerdir=$repo_path,upperdir=$upper_dir,workdir=$work_dir $overlay_root
    fi

    echo ":: Mounting necessary filesystems"
    for dir in dev proc sys run; do
        if  ! mountpoint -q "$chroot_dir/$dir"; then
            echo ":: Mounting $dir"
            mount --bind /$dir "$chroot_dir/$dir"
        else
            echo ":: $dir mount already exists"
        fi
    done

    echo ":: Mounting /dev/pts"
    if ! mountpoint -q "$chroot_dir/dev/pts"; then
        mkdir -p "$chroot_dir/dev/pts"
        mount -t devpts devpts "$chroot_dir/dev/pts"
    fi

    if [[ -S /var/run/docker.sock ]]; then
        echo ":: Mounting Docker socket"
        mkdir -p "$chroot_dir/var/run"
        if ! mountpoint -q "$chroot_dir/var/run/docker.sock"; then
            touch "$chroot_dir/var/run/docker.sock"
            mount --bind /var/run/docker.sock "$chroot_dir/var/run/docker.sock"
        fi
    else
        echo ":: Docker socket not found, skipping"
    fi

    echo ":: Setting up DNS resolution"
    mkdir -p "$chroot_dir/etc"

    if [[ ! -f "$chroot_dir/etc/resolv.conf" ]]; then
        cp /etc/resolv.conf "$chroot_dir/etc/resolv.conf"
    fi

    # Needed for the chroot environment
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    if [[ ! -z "${git_key_path}" ]]; then
        git_prov_key=$(cat "${git_key_path}")
        # export GIT_PROVISIONING_KEY="${git_prov_key}"
    fi

    # Add the packages needed for nix setup (prereq to nix environment setup)
    sudo chroot "$chroot_dir" /bin/sh -c "apk add --no-cache bash nix shadow procps sudo util-linux-login tini"

    sudo env \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        VAULT_ADDR="${VAULT_ADDR}" \
        VAULT_TOKEN="${VAULT_TOKEN}" \
        GIT_PROVISIONING_KEY="${git_prov_key}" \
        unshare --pid --mount-proc --fork --root="$chroot_dir" \
        /sbin/tini -- /homelab/scripts/metal_setup.sh
}

elevate_to_root(){
    if [[ $EUID -eq 0 ]]; then
        echo ":: Already running as root"
        return 0
    fi

    echo ":: Elevating to root..."
    exec sudo bash "$0" "${passed_args[@]}"
    return 0
}

passed_args=("$@")


# tiny bug -- order of params matters!!! e.g. -c -e WILL NOT clean up an elevated environment, but -e -c will!!!!!
while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--elevate)
            should_elevate=0
            shift
            ;;
        -p|--persist)
            should_cleanup=1
            shift
            ;;
        -c|--clean)
            should_cleanup=0

            if [[ $should_elevate -eq 0 ]]; then
                echo ":: Running nix environment with root privileges"
                elevate_to_root
            fi

            exit 0
            ;;
        -h|--help)
            help
            should_cleanup=1
            exit 0
            ;;
        -g|--git-key)
            shift
            git_key_path="$1"
            shift
            ;;
        *)
            echo "Error: Unknown option: $1"
            help
            should_cleanup=1
            exit 1
            ;;
    esac
done

command="$1"

if [[ $should_elevate -eq 0 ]]; then
    echo ":: Running nix environment with root privileges"
    elevate_to_root
    create_elevated_rootfs
else
    echo ":: Creating rootfs directory"
    mkdir -p rootfs

    extract_alpine_rootfs "rootfs"

    echo ":: Setting up proot environment"
    proot --kill-on-exit -r rootfs -0 -b /proc -b /dev -b /sys -b /etc/resolv.conf:/etc/resolv.conf -b ./:/prov -w "/home" /bin/sh -c "/sbin/apk add --no-cache bash nix shadow procps sudo && /usr/sbin/adduser -u 1000 -D keiichi" > /dev/null 2>&1

    echo ":: Setting up nix environment"
    proot --kill-on-exit -r rootfs -b /proc -b /dev -b /sys -b /nix -b /etc/resolv.conf:/etc/resolv.conf -b ./:/prov -w "/prov" env -i PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" VAULT_ADDR="${VAULT_ADDR}" VAULT_TOKEN="${VAULT_TOKEN}" /bin/bash scripts/nix_setup.sh "$command"
fi
