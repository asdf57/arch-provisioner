#!/usr/bin/env bash

set -eu

print_help() {
    echo "Usage: run_archiso [options]"
    echo ""
    echo "Options:"
    echo "  -i [image]      Image to boot into"
    echo "  -n [size]       Create a new disk image with the specified size (e.g. 10G)"
    echo "  -u              Use UEFI boot"
    echo "  -c [cores]      Number of CPU cores (default: 2)"
    echo "  -r [ram]        Amount of RAM in MB (default: 3072)"
    echo "  -h              Print help"
    echo ""
    echo "Example:"
    echo "  Run an image using UEFI:"
    echo "  $ run_archiso -u -i archiso-2020.05.23-x86_64.iso -n 10G -c 4 -r 4096"
}

create_disk() {
    local disk_path="$1"
    local disk_size="$2"
    qemu-img create -f qcow2 "$disk_path" "$disk_size"
}

run_image() {
    local image="$1"
    local disk_path="$2"
    local boot_type="$3"
    local cpu_cores="$4"
    local ram_size="$5"
    local qemu_options=()

    if [[ "$boot_type" == "uefi" ]]; then
        qemu_options+=(
            '-drive' "if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.fd"
            '-drive' "if=pflash,format=raw,file=/usr/share/edk2/x64/OVMF_VARS.fd"
        )
    fi

    qemu-system-x86_64 \
        -enable-kvm \
        -cpu host \
        -smp "$cpu_cores" \
        -m "$ram_size" \
        -boot order=d,menu=on,reboot-timeout=5000 \
        -drive "file=$image,media=cdrom" \
        -drive "file=$disk_path,if=virtio,format=qcow2" \
        -net user,hostfwd=tcp::60022-:22 -net nic \
        -name archiso \
        "${qemu_options[@]}" \
        -serial stdio \
        -no-reboot
}

image=""
disk_size=""
boot_type="bios"
cpu_cores=2
ram_size=3072
script_dir=$(dirname "$(realpath "$0")")
disk_path="$script_dir/disk.img"

if (( $# > 0 )); then
    while getopts 'hi:n:uc:r:' flag; do
        case "$flag" in
            i) image="$OPTARG" ;;
            n) disk_size="$OPTARG" ;;
            u) boot_type="uefi" ;;
            c) cpu_cores="$OPTARG" ;;
            r) ram_size="$OPTARG" ;;
            h) print_help; exit 0 ;;
            *) echo "Error: Invalid option"; print_help; exit 1 ;;
        esac
    done
else
    print_help
    exit 1
fi

if [[ -z "$image" ]]; then
    echo "Error: Image not specified"
    print_help
    exit 1
fi

if [[ -n "$disk_size" ]]; then
    create_disk "$disk_path" "$disk_size"
fi

run_image "$image" "$disk_path" "$boot_type" "$cpu_cores" "$ram_size"
