#!/bin/bash
# Check for --bare flag
BARE_MODE=false
KUBECTL_ARGS=()

# Packages to install in bare mode
# shellcheck disable=SC2034
BARE_NIX_PACKAGES=(
	"nixpkgs#iputils"
	"nixpkgs#bind"
)

for arg in "$@"; do
	if [ "$arg" = "--bare" ]; then
		BARE_MODE=true
	else
		KUBECTL_ARGS+=("$arg")
	fi
done

# Generate unique pod name
POD_NAME="nix-cloud-shell-$(date +%s)"

# Expand BARE_NIX_PACKAGES array into a space-separated string for use in the command
BARE_PACKAGES_STR="${BARE_NIX_PACKAGES[*]}"

echo "Starting pod $POD_NAME..."
echo "Type 'exit' to leave the pod. The pod will be deleted automatically."

# Run the pod with --rm to auto-delete when it exits
# activeDeadlineSeconds: terminate pod after 6 hours if still running
kubectl "${KUBECTL_ARGS[@]}" run "$POD_NAME" --rm -it --restart=Never \
	--image=nixos/nix:latest \
	--env="HOME=/home/addg" \
	--env="USER=addg" \
	--env="BARE_MODE=$BARE_MODE" \
	--env="BARE_PACKAGES_STR=$BARE_PACKAGES_STR" \
	--overrides='{"spec":{"activeDeadlineSeconds":21600}}' \
	-- sh -c "
    set -e

    # Enable flakes and nix-command
    mkdir -p ~/.config/nix
    {
      echo 'experimental-features = nix-command flakes'
      echo 'accept-flake-config = true'
      echo 'max-jobs = 4'
      echo 'cores = 4'
    } > ~/.config/nix/nix.conf

    if [ \"\$BARE_MODE\" = \"true\" ]; then
      # Bare mode - nix with zsh and oh-my-zsh, no home-manager
      echo \"=====================================\"
      echo \"Bare Nix Shell (zsh + oh-my-zsh)\"
      echo \"=====================================\"

      # Install zsh, oh-my-zsh, syntax highlighting, and autosuggestions using nix profile
      # Note: glibc provides iconv command needed by oh-my-zsh
      nix profile install nixpkgs#zsh nixpkgs#oh-my-zsh nixpkgs#zsh-syntax-highlighting nixpkgs#zsh-autosuggestions nixpkgs#glibc nixpkgs#coreutils \$BARE_PACKAGES_STR

      # Set up minimal zshrc with oh-my-zsh, syntax highlighting, and autosuggestions
      echo \"export ZSH=\$HOME/.nix-profile/share/oh-my-zsh\" > ~/.zshrc
      echo 'ZSH_THEME=\"robbyrussell\"' >> ~/.zshrc
      echo 'plugins=(git)' >> ~/.zshrc
      echo 'source \$ZSH/oh-my-zsh.sh' >> ~/.zshrc
      echo 'source \$HOME/.nix-profile/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> ~/.zshrc
      echo 'source \$HOME/.nix-profile/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> ~/.zshrc

      cd \"\$HOME\"

      # Add nix profile to PATH and set SHELL env var
      export PATH=\"\$HOME/.nix-profile/bin:\$PATH\"
      export SHELL=\"\$HOME/.nix-profile/bin/zsh\"
      exec zsh
    else
      # Full mode with home-manager
      mkdir -p ~/.local/state/nix/profiles

      echo \"Activating cloud-shell home-manager configuration...\"
      nix run home-manager/master -- switch --impure --show-trace --flake \"git+https://github.com/AddG0/nix-config?ref=main#cloud-shell\" -b backup

      echo \"=====================================\"
      echo \"Welcome to cloud-shell environment!\"
      echo \"Configuration: AddG0/nix-config\"
      echo \"=====================================\"

      cd \"\$HOME\"
      exec env PATH=\"\$HOME/.nix-profile/bin:\$PATH\" SHELL=\"\$HOME/.nix-profile/bin/zsh\" zsh -l
    fi
  "
