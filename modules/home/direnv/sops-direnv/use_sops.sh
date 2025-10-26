#!/usr/bin/env bash
# SOPS direnv integration function

use_sops() {
  local path=${1:-$PWD/secrets.yaml}
  if [ -e "$path" ]; then
    if grep -q -E '^sops:' "$path"; then
      eval "$(sops -d --output-type dotenv "$path" 2>/dev/null | direnv dotenv bash /dev/stdin || false)"
    else
      if [ -n "$(command -v yq)" ]; then
        eval "$(yq eval -o=props "$path" | direnv dotenv bash /dev/stdin)"
      fi
    fi
  fi
  watch_file "$path"
}
