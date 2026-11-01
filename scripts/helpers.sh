#!/usr/bin/env bash
set -eo pipefail

### Logging helpers

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Debug flag - can be set via -v argument
DEBUG_MODE=false

# Function to handle verbose flag
handle_verbose_flag() {
  while getopts "v" opt; do
    case "$opt" in
    v) DEBUG_MODE=true ;;
    *) ;;
    esac
  done
  shift $((OPTIND - 1))
}

function log_debug() {
  if [ "$DEBUG_MODE" = true ]; then
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $1${NC}"
    if [ -n "${2-}" ]; then
      echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $($2)${NC}"
    fi
  fi
}

function log_info() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1${NC}"
  if [ -n "${2-}" ]; then
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $($2)${NC}"
  fi
}

function log_warning() {
  echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1${NC}"
  if [ -n "${2-}" ]; then
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $($2)${NC}"
  fi
}

function log_error() {
  echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1${NC}"
  if [ -n "${2-}" ]; then
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $($2)${NC}"
  fi
}

### UX helpers

function red() {
  echo -e "\x1B[31m[!] $1 \x1B[0m"
  if [ -n "${2-}" ]; then
    echo -e "\x1B[31m[!] $($2) \x1B[0m"
  fi
}

function green() {
  echo -e "\x1B[32m[+] $1 \x1B[0m"
  if [ -n "${2-}" ]; then
    echo -e "\x1B[32m[+] $($2) \x1B[0m"
  fi
}

function blue() {
  echo -e "\x1B[34m[*] $1 \x1B[0m"
  if [ -n "${2-}" ]; then
    echo -e "\x1B[34m[*] $($2) \x1B[0m"
  fi
}

function yellow() {
  echo -e "\x1B[33m[*] $1 \x1B[0m"
  if [ -n "${2-}" ]; then
    echo -e "\x1B[33m[*] $($2) \x1B[0m"
  fi
}

# Ask yes or no, with yes being the default
function yes_or_no() {
  echo -en "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $* [y/n] (default: y): ${NC}"
  while true; do
    # End of input answers no, whatever the default.
    read -rp "" yn || return 1
    yn=${yn:-y}
    case $yn in
    [Yy]*) return 0 ;;
    [Nn]*) return 1 ;;
    esac
  done
}

# Ask yes or no, with no being the default
function no_or_yes() {
  echo -en "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $* [y/n] (default: n): ${NC}"
  while true; do
    # End of input answers no, whatever the default.
    read -rp "" yn || return 1
    yn=${yn:-n}
    case $yn in
    [Yy]*) return 0 ;;
    [Nn]*) return 1 ;;
    esac
  done
}

function is_git_repo() {
  git rev-parse --git-dir >/dev/null 2>&1
}

### SOPS helpers
# nix-secrets lives at its ghq-standard checkout, not beside nix-config. No ghq = machine not
# set up for secrets, so leave it unset; callers gate on HAS_NIX_SECRETS to skip secrets actions.
if [[ -z ${NIX_SECRETS_DIR:-} ]] && command -v ghq >/dev/null 2>&1; then
  NIX_SECRETS_DIR="$(ghq root)/github.com/AddG0/nix-secrets"
fi
nix_secrets_dir=${NIX_SECRETS_DIR:-}
if [[ -n $nix_secrets_dir && -d $nix_secrets_dir ]]; then
  HAS_NIX_SECRETS=1
else
  HAS_NIX_SECRETS=0
fi
SOPS_FILE="${nix_secrets_dir}/.sops.yaml"

# Updates the .sops.yaml file with a new host or user age key.
function sops_update_age_key() {
  field="$1"
  keyname="$2"
  key="$3"

  if [ ! "$field" == "hosts" ] && [ ! "$field" == "users" ]; then
    red "Invalid field passed to sops_update_age_key. Must be either 'hosts' or 'users'."
    exit 1
  fi

  if [[ -n $(yq ".keys.${field}[] | select(anchor == \"$keyname\")" "${SOPS_FILE}") ]]; then
    green "Updating existing ${keyname} key"
    yq -i "(.keys.${field}[] | select(anchor == \"$keyname\")) = \"$key\"" "$SOPS_FILE"
  else
    green "Adding new ${keyname} key"
    yq -i ".keys.$field += [\"$key\"] | .keys.${field}[-1] anchor = \"$keyname\"" "$SOPS_FILE"
  fi
}
