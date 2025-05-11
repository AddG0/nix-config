NIX_SECRETS_DIR := "../nix-secrets"
SOPS_FILE := "{{NIX_SECRETS_DIR}}/secrets.yaml"
IS_DARWIN := if os() == "macos" { "true" } else { "false" }
DEFAULT_USER := "addg"

# default recipe to display help information
default:
  @just --list

pre:
  git pull || true
  git add '**/*'

check-pre:
  if {{IS_DARWIN}}; then \
    echo "$(tput setaf 3)Warning: On Darwin systems, only Darwin-specific configurations can be validated. Linux-specific packages and configurations will error out.$(tput sgr0)"; \
  fi

rebuild-pre: pre && update-personal-repos

rebuild-post:
  just check-sops

check: check-pre && pre
  nix flake check --impure --keep-going
  # cd nixos-installer && nix flake check --impure --keep-going

check-trace: check-pre && pre
  nix flake check --impure --show-trace
  cd nixos-installer && nix flake check --impure --show trace

alias r := rebuild
# Add --option eval-cache false if you end up caching a failure you can't get around
rebuild hostname="": rebuild-pre
  scripts/rebuild.sh {{hostname}}

alias rf := rebuild-full

# Requires sops to be running and you must have reboot after initial rebuild
rebuild-full hostname="": rebuild-pre && rebuild-post
  scripts/rebuild.sh {{hostname}}
  just check

# Requires sops to be running and you must have reboot after initial rebuild
rebuild-trace hostname="": rebuild-pre && rebuild-post
  scripts/rebuild.sh -t {{hostname}}
  just check

clean:
  nix-collect-garbage
  nix-store --gc

# Debug host configuration in nix repl
debug hostname="$(hostname)":
  if {{IS_DARWIN}}; then \
    nix repl .#darwinConfigurations.{{hostname}}.system; \
  else \
    nix repl .#nixosConfigurations.{{hostname}}.system; \
  fi

eval attr="" hostname="$(hostname)"  :
  if {{IS_DARWIN}}; then \
    nix eval .#darwinConfigurations.{{hostname}}.{{attr}} --json | jq; \
  else \
    nix eval .#nixosConfigurations.{{hostname}}.{{attr}} --json | jq; \
  fi

alias u := update

update *ARGS:
  nix flake update {{ARGS}}

rebuild-update: update && rebuild

update-packages *ARGS:
  scripts/update-packages.sh {{ARGS}}

alias d := diff

diff:
  git diff ':!flake.lock'

sops:
  echo "Editing {{SOPS_FILE}}"
  nix-shell -p sops --run "SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops {{SOPS_FILE}}"

age-key:
  nix-shell -p age --run "age-keygen"

rekey:
  cd {{NIX_SECRETS_DIR}} && (\
    sops updatekeys -y secrets.yaml && \
    (pre-commit run --all-files || true) && \
    git add -u && (git commit -m "chore: rekey" || true) && git push \
  )

check-sops:
  scripts/check-sops.sh

update-personal-repos:
  (cd {{NIX_SECRETS_DIR}} && git fetch && git rebase) || true
  nix flake update nix-secrets || true
  nix flake update pterodactyl-addons || true

iso:
  # If we dont remove this folder, libvirtd VM doesnt run with the new iso...
  rm -rf result
  nix build ./nixos-installer#nixosConfigurations.iso.config.system.build.isoImage

iso-install DRIVE: iso
  sudo dd if=$(eza --sort changed result/iso/*.iso | tail -n1) of={{DRIVE}} bs=4M status=progress oflag=sync

disko DRIVE PASSWORD:
  echo "{{PASSWORD}}" > /tmp/disko-password
  sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
    --mode disko \
    disks/btrfs-luks-impermanence-disko.nix \
    --arg disk '"{{DRIVE}}"' \
    --arg password '"{{PASSWORD}}"'
  rm /tmp/disko-password

sync HOST USER=DEFAULT_USER:
  rsync -av --filter=':- .gitignore' --exclude='.git/hooks' -e "ssh -l {{USER}}" . {{USER}}@{{HOST}}:nix-config/

sync-secrets HOST USER=DEFAULT_USER:
  rsync -av --filter=':- .gitignore' -e "ssh -l {{USER}}" . {{USER}}@{{HOST}}:nix-secrets/

sync-ssh HOST USER=DEFAULT_USER:
  rsync -av -L -e "ssh -l {{USER}}" ~/.ssh/id_ed25519* {{USER}}@{{HOST}}:~/.ssh/

nixos-anywhere HOSTNAME IP USER="root" SSH_OPTS="": rebuild-pre
  echo "{{IS_DARWIN}}"
  nix run github:nix-community/nixos-anywhere -- \
    {{ if IS_DARWIN == "true" { "--build-on-remote" } else { "" } }} \
    --generate-hardware-config nixos-generate-config ./hosts/nixos/{{HOSTNAME}}/hardware-configuration.nix \
    --option accept-flake-config true --debug \
    --flake .#{{HOSTNAME}} {{USER}}@{{IP}} {{SSH_OPTS}}
