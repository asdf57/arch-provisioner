#!/usr/bin/env bash

set -euo pipefail

template_file="${1:-.env}"
shared_file="${2:-.env.shared}"
local_file="${3:-.env.local}"

if [[ ! -f "$template_file" ]]; then
  echo "Template env file $template_file does not exist." >&2
  exit 1
fi

if [[ ! -f "$shared_file" ]]; then
  echo "Shared bootstrap config $shared_file does not exist." >&2
  exit 1
fi

if [[ ! -f "$local_file" ]]; then
  echo "Local bootstrap config $local_file does not exist." >&2
  exit 1
fi

declare -A values
declare -A rendered

load_values() {
  local file="$1"
  local line key value

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" != *=* ]] && continue

    key="${line%%=*}"
    value="${line#*=}"
    key="${key//[[:space:]]/}"

    values["$key"]="$value"
  done < "$file"
}

load_values "$shared_file"
load_values "$local_file"

tmp_file="$(mktemp)"

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^([A-Z0-9_]+)= ]]; then
    key="${BASH_REMATCH[1]}"
    if [[ -v values["$key"] ]]; then
      printf '%s=%s\n' "$key" "${values[$key]}" >> "$tmp_file"
      rendered["$key"]=1
    else
      printf '%s\n' "$line" >> "$tmp_file"
    fi
  else
    printf '%s\n' "$line" >> "$tmp_file"
  fi
done < "$template_file"

for key in "${!values[@]}"; do
  if [[ ! -v rendered["$key"] ]]; then
    printf '%s=%s\n' "$key" "${values[$key]}" >> "$tmp_file"
  fi
done

mv "$tmp_file" "$template_file"

echo ":: Rendered $template_file from $shared_file and $local_file"
