#!/bin/bash
set -euo pipefail

# Bootstrap script for nix + home-manager in ephemeral environments (Google Cloud Shell, etc.)
# Usage: curl -L https://raw.githubusercontent.com/AddG0/nix-config/main/scripts/setup-cloud-shell.sh | bash

FLAKE_URL="git+https://github.com/AddG0/nix-config?ref=main#cloud-shell"

log() { echo "[setup] $*"; }

# Install Nix if not present
if ! command -v nix &>/dev/null; then
  log "Installing Nix..."
  sh <(curl -L https://nixos.org/nix/install) --no-daemon
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Run home-manager
log "Activating home-manager configuration..."
NIX_CONFIG="experimental-features = nix-command flakes" \
  nix run home-manager/master -- switch --impure --flake "$FLAKE_URL" -b backup

log "Done! Starting zsh..."
SHELL="$HOME/.nix-profile/bin/zsh" exec "$HOME/.nix-profile/bin/zsh" -l
