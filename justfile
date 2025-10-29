NIX_SECRETS_DIR := "../nix-secrets"
SOPS_FILE := "{{NIX_SECRETS_DIR}}/secrets.yaml"
IS_DARWIN := if os() == "macos" { "true" } else { "false" }
USE_NH_DEFAULT := if os() == "linux" { "true" } else { "false" }
DEFAULT_USER := "addg"

# default recipe to display help information
default:
  @just --list

[private]
[doc("Pull latest changes and stage all files")]
pre:
  git pull || true
  git add '**/*'

[private]
[doc("Display platform-specific warning for Darwin systems")]
check-pre:
  if {{IS_DARWIN}}; then \
    echo "$(tput setaf 3)Warning: On Darwin systems, only Darwin-specific configurations can be validated. Linux-specific packages and configurations will error out.$(tput sgr0)"; \
  fi

[private]
[doc("Update personal repositories and dependencies")]
rebuild-pre: pre && update-personal-repos

[private]
[doc("Validate SOPS configuration after rebuild")]
rebuild-post:
  just check-sops

[group('validation')]
[doc("Check flake configuration with pre-validation warnings")]
check: check-pre && pre
  nix flake check --keep-going
  # cd nixos-installer && nix flake check --keep-going

[group('validation')]
[doc("Check flake configuration with detailed trace output")]
check-trace: check-pre && pre
  nix flake check --show-trace
  cd nixos-installer && nix flake check --show trace

alias r := rebuild

# Add --option eval-cache false if you end up caching a failure you can't get around
[group('system')]
[doc("Rebuild system configuration for specified hostname")]
rebuild hostname="" use-nh=USE_NH_DEFAULT: rebuild-pre
  USE_NH={{use-nh}} scripts/rebuild.sh {{hostname}}

[group('system')]
[doc("Rollback to previous generation or specific generation number")]
rollback generation="":
  scripts/rollback.sh {{generation}}

[group('system')]
[doc("List system generations")]
list-generations:
  nixos-rebuild list-generations

alias rf := rebuild-full

# Requires sops to be running and you must have reboot after initial rebuild
[group('system')]
[doc("Full system rebuild with validation - requires SOPS and reboot after initial rebuild")]
rebuild-full hostname="": rebuild-pre && rebuild-post
  scripts/rebuild.sh {{hostname}}
  just check

# Requires sops to be running and you must have reboot after initial rebuild
[group('system')]
[doc("Rebuild with trace output for debugging")]
rebuild-trace hostname="": rebuild-pre && rebuild-post
  scripts/rebuild.sh -t {{hostname}}
  just check

[group('maintenance')]
[confirm("This will remove all unused Nix store paths. Continue?")]
[doc("Clean up Nix store and collect garbage")]
clean:
  nix-collect-garbage
  nix-store --gc

# Debug host configuration in nix repl
[group('development')]
[doc("Debug host configuration in nix repl")]
debug hostname="$(hostname)":
  if {{IS_DARWIN}}; then \
    nix repl .#darwinConfigurations.{{hostname}}.system; \
  else \
    nix repl .#nixosConfigurations.{{hostname}}.system; \
  fi

[group('development')]
[doc("Evaluate and display configuration attributes")]
eval attr="" hostname="$(hostname)"  :
  if {{IS_DARWIN}}; then \
    nix eval .#darwinConfigurations.{{hostname}}.{{attr}} --json | jq; \
  else \
    nix eval .#nixosConfigurations.{{hostname}}.{{attr}} --json | jq; \
  fi

alias u := update

[group('dependencies')]
[doc("Update flake inputs")]
update *ARGS:
  nix flake update {{ARGS}}

[group('system')]
[doc("Update dependencies then rebuild system")]
rebuild-update: update && rebuild

[group('dependencies')]
[doc("Update specific packages using custom script")]
update-packages *ARGS:
  scripts/update-packages.sh {{ARGS}}

[group('development')]
[doc("Show git diff excluding flake.lock")]
diff:
  git diff ':!flake.lock'

[group('secrets')]
[doc("Edit encrypted secrets file using SOPS")]
sops:
  @echo "Editing {{SOPS_FILE}}"
  nix-shell -p sops --run "SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops {{SOPS_FILE}}"

[group('secrets')]
[doc("Generate new age encryption key")]
age-key:
  nix-shell -p age --run "age-keygen"

[group('secrets')]
[confirm("This will update all encryption keys. Continue?")]
[doc("Update all SOPS encryption keys")]
rekey:
  cd {{NIX_SECRETS_DIR}} && (\
    sops updatekeys -y secrets.yaml && \
    (pre-commit run --all-files || true) && \
    git add -u && (git commit -m "chore: rekey" || true) && git push \
  )

[group('validation')]
[doc("Validate SOPS configuration")]
check-sops:
  scripts/check-sops.sh

[private]
[doc("Update personal repositories and flake inputs")]
update-personal-repos:
  (cd {{NIX_SECRETS_DIR}} && git fetch && git rebase) || true
  nix flake update nix-secrets || true
  nix flake update pterodactyl-addons lumenboard-player || true

[group('installation')]
[doc("Build NixOS ISO image")]
iso:
  # If we dont remove this folder, libvirtd VM doesnt run with the new iso...
  rm -rf result
  nix build ./nixos-installer#nixosConfigurations.iso.config.system.build.isoImage

[group('installation')]
[confirm("This will overwrite the target drive. Continue?")]
[doc("Install ISO to specified drive")]
iso-install DRIVE: iso
  sudo dd if=$(eza --sort changed result/iso/*.iso | tail -n1) of={{DRIVE}} bs=4M status=progress oflag=sync

[group('installation')]
[confirm("This will partition and encrypt the drive. All data will be lost. Continue?")]
[doc("Partition and encrypt drive using disko")]
disko DRIVE PASSWORD:
  @{{ if DRIVE == "" { error("Drive parameter cannot be empty") } else { "" } }}
  @{{ if PASSWORD == "" { error("Password parameter cannot be empty") } else { "" } }}
  echo "{{PASSWORD}}" > /tmp/disko-password
  sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
    --mode disko \
    disks/btrfs-luks-impermanence-disko.nix \
    --arg disk '"{{DRIVE}}"' \
    --arg password '"{{PASSWORD}}"'
  rm /tmp/disko-password

[group('deployment')]
[doc("Sync configuration to remote host")]
sync HOST USER=DEFAULT_USER:
  @{{ if HOST == "" { error("HOST parameter is required") } else { "" } }}
  rsync -av --filter=':- .gitignore' --exclude='.git' -e "ssh -l {{USER}}" . {{USER}}@{{HOST}}:nix-config/

[group('deployment')]
[doc("Sync secrets to remote host")]
sync-secrets HOST USER=DEFAULT_USER:
  @{{ if HOST == "" { error("HOST parameter is required") } else { "" } }}
  rsync -av --filter=':- .gitignore' -e "ssh -l {{USER}}" . {{USER}}@{{HOST}}:nix-secrets/

[group('deployment')]
[doc("Sync SSH keys to remote host")]
sync-ssh HOST USER=DEFAULT_USER:
  @{{ if HOST == "" { error("HOST parameter is required") } else { "" } }}
  rsync -av -L -e "ssh -l {{USER}}" ~/.ssh/id_ed25519* {{USER}}@{{HOST}}:~/.ssh/

[group('deployment')]
[doc("Deploy NixOS to remote host using nixos-anywhere")]
nixos-anywhere HOSTNAME IP USER="root" SSH_OPTS="": rebuild-pre
  @{{ if HOSTNAME == "" { error("HOSTNAME parameter is required") } else { "" } }}
  @{{ if IP == "" { error("IP parameter is required") } else { "" } }}
  echo "{{IS_DARWIN}}"
  nix run github:nix-community/nixos-anywhere -- \
    {{ if IS_DARWIN == "true" { "--build-on-remote" } else { "" } }} \
    --generate-hardware-config nixos-generate-config ./hosts/nixos/{{HOSTNAME}}/hardware-configuration.nix \
    --option accept-flake-config true --debug \
    --flake .#{{HOSTNAME}} {{USER}}@{{IP}} {{SSH_OPTS}}

# Colmena deployment commands
alias d := deploy

[group('deployment')]
[doc("Deploy using colmena (specify hostname or deploys to all, use --dry for dry-run)")]
deploy hostname="" dry="false": rebuild-pre
  colmena apply --impure {{ if hostname != "" { "--on " + hostname } else { "" } }} {{ if dry == "true" { "dry-activate" } else { "" } }}

[group('deployment')]
[doc("Build configuration without deploying (specify hostname or builds all)")]
deploy-build hostname="":
  colmena build --impure {{ if hostname != "" { "--on " + hostname } else { "" } }}

[group('deployment')]
[doc("Upload keys (specify hostname or uploads to all)")]
deploy-keys hostname="":
  colmena upload-keys --impure {{ if hostname != "" { "--on " + hostname } else { "" } }}

[group('deployment')]
[doc("List all available colmena hosts")]
deploy-list:
  @nix eval .#colmena --apply 'x: builtins.filter (n: n != "meta") (builtins.attrNames x)' --json | jq -r '.[]'

[group('deployment')]
[doc("Execute command via colmena (specify hostname or executes on all)")]
deploy-exec cmd="" hostname="":
  @{{ if cmd == "" { error("cmd parameter is required") } else { "" } }}
  colmena exec --impure {{ if hostname != "" { "--on " + hostname } else { "" } }} -- {{cmd}}


# Below is random commands incase I forget

[group('system')]
[doc("Manually create systemd temporary files")]
tmpfiles-create:
  sudo systemd-tmpfiles --create
