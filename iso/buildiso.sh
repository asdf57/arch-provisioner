#!/bin/bash

# Builds an ISO for the specified linux distribution

set -euo pipefail

help_message="Usage: $0 -b <distro> [-o <output_dir>] [-s <ssh key name>] [-v] [-h]
  -b  The distribution to build the ISO for. Valid values are:
      debian, ubuntu, gentoo, arch
  -o  The output directory to write the ISO  (relative to the specified distro directory)
  -v  Enable verbose mode
  -h  Display this help message"

container_ssh_key_name="ansible_provisioning_key"
supported_distros=("debian" "ubuntu" "gentoo" "arch")

output_dir="out"
distro=""
provisioning_key_name="ansible_provisioning_key"

function parse_cli_args() {
  while getopts "b:o:s:vh" opt; do
    case ${opt} in
      b )
        distro=$OPTARG
        ;;
      o )
        output_dir=$OPTARG
        ;;
      s )
        provisioning_key_name=$OPTARG
        ;;
      v )
        set -x
        ;;
      h )
        echo "$help_message"
        exit 0
        ;;
      \? )
        echo "Invalid option: -$OPTARG" >&2
        echo "$help_message" >&2
        exit 1
        ;;
      : )
        echo "Option -$OPTARG requires an argument." >&2
        echo "$help_message" >&2
        exit 1
        ;;
    esac
  done
  shift $((OPTIND -1))

  if [[ -z "$distro" ]]; then
    echo "Error: -b <distro> is required." >&2
    echo "$help_message" >&2
    exit 1
  fi

  if [[ ! " ${supported_distros[@]} " =~ " $distro " ]]; then
    echo "Invalid distribution: $distro" >&2
    echo "$help_message" >&2
    exit 1
  fi
}

function build_iso() {
  # Check if the public SSH key for Ansible is present
  if [[ ! -f "$HOME/.ssh/$provisioning_key_name.pub" ]]; then
    echo "- Public SSH key for Ansible not found, will recreate!" >&2
    ssh-keygen -t ed25519 -f "$HOME/.ssh/$provisioning_key_name" -N ""
  fi

  echo "- SSH key at $HOME/.ssh/$provisioning_key_name.pub found!"

  echo "- Changing cwd to $distro"
  pushd "$distro"

  # Set up trap to clean up on exit or crash after entering the distro directory
  trap cleanup EXIT

  echo "- Creating temporary copy of SSH key to allow Docker to copy it"
  cp "$HOME/.ssh/$provisioning_key_name.pub" "$container_ssh_key_name.pub"
  
  echo "- Set iso output directory to $output_dir"
  if [[ ! -d "$output_dir" ]]; then
    echo "- Output directory $output_dir does not exist, creating it!"
    mkdir -p "$output_dir"
  fi

  case $distro in
    debian )
      echo "not implemented"
      ;;
    ubuntu )
      echo "not implemented"
      ;;
    gentoo )
      echo "not implemented"
      ;;
    arch )
      docker build --platform linux/amd64 -t arch-iso-builder .
      docker run --platform linux/amd64 --privileged --rm -v $(pwd)/$output_dir:/output arch-iso-builder
      ;;
  esac

  echo "- ISO built successfully!"
}

function cleanup() {
  if [[ -f "$container_ssh_key_name.pub" ]]; then
    echo "- Removing temporary SSH key copy"
    rm -f "$container_ssh_key_name.pub"
  fi

  popd
}

function main() {
  parse_cli_args "$@"
  build_iso
  echo "$distro ISO placed in $output_dir"
}

main "$@"
