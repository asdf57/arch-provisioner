#!/bin/bash

# Builds an ISO for the specified linux distribution

set -euo pipefail

help_message="Usage: $0 [-h] [-o <output_dir>] [-v] <distro> [options]
  Build an ISO for the specified distribution

  Positional arguments:
    <distro>  The distribution to build an ISO for

  Flags:
    -o  The output directory to write the ISO into  (relative to the specified distro directory)
    -v  Enable verbose mode
    -h  Display this help message"

readonly PROV_KEY_NAME="provisioning_key"
readonly SUPPORTED_DISTROS=("arch" "debian")

distro=""
output_dir="out"
distro_flags=""

function parse_cli_args() {
  while getopts "o:vh" opt; do
    case ${opt} in
      o )
        output_dir=$OPTARG
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

  # Remove the parsed options from the positional parameters
  shift $((OPTIND -1))

  distro="$1"

  if [[ -z "$distro" ]]; then
    echo "Error: distro is required." >&2
    echo "$help_message" >&2
    exit 1
  fi

  if [[ ! " ${SUPPORTED_DISTROS[@]} " =~ " $distro " ]]; then
    echo "Invalid distribution: $distro" >&2
    echo "$help_message" >&2
    exit 1
  fi

  shift
  distro_flags="$@"
}

function build() {
  echo ":: Building ISO for $distro"

  # Check if the public SSH key for Ansible is present
  if [[ ! -f "$HOME/.ssh/$PROV_KEY_NAME.pub" ]]; then
    echo "- Public SSH key for Ansible not found, will recreate!" >&2
    ssh-keygen -t ed25519 -f "$HOME/.ssh/$PROV_KEY_NAME" -N ""
  fi

  echo "=> SSH key at $HOME/.ssh/$PROV_KEY_NAME.pub found!"

  echo "=> Creating temporary copy of SSH key to allow Docker to copy it"
  cp "$HOME/.ssh/$PROV_KEY_NAME.pub" "$PROV_KEY_NAME.pub"
  
  echo "=> Set output directory to $output_dir"
  if [[ ! -d "$output_dir" ]]; then
    echo "=> Output directory $output_dir does not exist, creating it!"
    mkdir -p "$output_dir"
  fi

  # Set inheritable environment variables
  export OUTPUT_DIR="$output_dir"

  case $distro in
    arch )
      echo "$distro_flags"
      docker build --no-cache --platform linux/amd64 -t arch-builder -f Dockerfile.arch .
      docker run --rm --platform linux/amd64 --privileged -e PARAMS="$distro_flags" -v $(pwd)/$OUTPUT_DIR:/output arch-builder
      ;;

    debian )
      docker build --no-cache --platform linux/amd64 -t debian-builder -f Dockerfile.debian .
      docker run --rm --platform linux/amd64 --privileged -v $(pwd)/$OUTPUT_DIR:/output debian-builder
      ;;
  esac

  echo ":: File built successfully!"
  echo "=> $distro ISO placed in $output_dir"
}

function cleanup() {
  echo ":: Running cleanup hook"
  if [[ -f "$PROV_KEY_NAME.pub" ]]; then
    echo "=> Removing temporary SSH key copy"
    rm -f "$PROV_KEY_NAME.pub"
  fi
}

trap cleanup EXIT

parse_cli_args "$@"
build
