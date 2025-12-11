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
  @find . -type l -name 'result*' -delete 2>/dev/null || true
  nix-collect-garbage
  nix-store --gc

[group('maintenance')]
[confirm("This will remove all unused Nix store paths and optimize. This may take a while. Continue?")]
[doc("Deep clean with store optimization (slower but reclaims more space)")]
clean-deep:
  @echo "Before: $(du -sh /nix/store | cut -f1)"
  @find . -type l -name 'result*' -delete 2>/dev/null || true
  nix-collect-garbage
  nix-store --gc
  @echo "Optimizing store (this will take a while)..."
  nix-store --optimize
  @echo "After: $(du -sh /nix/store | cut -f1)"

[group('maintenance')]
[doc("Visualize Nix store dependencies interactively")]
tree:
  nix-tree /run/current-system

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

[group('development')]
[doc("Analyze Nix evaluation performance using trace profiling")]
profile hostname="" use-existing="y":
  scripts/analyze-trace.sh {{ if hostname != "" { hostname } else { "$(hostname)" } }} {{use-existing}}

[group('development')]
[doc("Benchmark evaluation performance between feature branch and base (defaults to main)")]
benchmark feature-branch base-branch="main" hostname="" iterations="3":
  @{{ if feature-branch == "" { error("feature-branch parameter is required") } else { "" } }}
  scripts/benchmark-eval.sh {{feature-branch}} {{base-branch}} {{ if hostname != "" { hostname } else { "$(hostname)" } }} {{iterations}}

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
  nix flake update nix-secrets pterodactyl-addons lumenboard-player ai-toolkit || true

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
[doc("Watch filesystem and sync configuration to remote host on changes")]
sync-watch HOST USER=DEFAULT_USER:
  @{{ if HOST == "" { error("HOST parameter is required") } else { "" } }}
  rsync -av --filter=':- .gitignore' --exclude='.git' -e "ssh -l {{USER}}" . {{USER}}@{{HOST}}:nix-config/
  @if [ "$(uname)" = "Darwin" ]; then \
    nix run nixpkgs#fswatch -- -o --exclude='\.git' . | while read -r _; do \
      rsync -av --filter=':- .gitignore' --exclude='.git' -e "ssh -l {{USER}}" . {{USER}}@{{HOST}}:nix-config/; \
    done; \
  else \
    while true; do \
      inotifywait -r -e modify,create,delete,move --exclude '\.git' .; \
      rsync -av --filter=':- .gitignore' --exclude='.git' -e "ssh -l {{USER}}" . {{USER}}@{{HOST}}:nix-config/; \
    done; \
  fi

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

[group('utilities')]
[doc("Manually create systemd temporary files")]
tmpfiles-create:
  sudo systemd-tmpfiles --create

[group('utilities')]
[doc("Restart Plasma shell (KDE Plasma desktop)")]
restart-plasma:
  #!/usr/bin/env bash
  if pgrep plasmashell > /dev/null; then \
    echo "Restarting Plasma shell..."; \
    pkill plasmashell && sleep 2 && plasmashell > /dev/null 2>&1 & \
    echo "Plasma shell restarted"; \
  else \
    echo "Plasma shell is not running, starting it..."; \
    plasmashell > /dev/null 2>&1 & \
    echo "Plasma shell started"; \
  fi

# K3s cluster management commands

# Helper to run command locally or via SSH based on hostname
[private]
_run-on HOST USER CMD:
  #!/usr/bin/env bash
  if [ "{{HOST}}" = "$(hostname)" ] || [ "{{HOST}}" = "$(hostname -s)" ]; then
    eval "{{CMD}}"
  else
    ssh -t -l {{USER}} {{HOST}} '{{CMD}}'
  fi

[group('k3s')]
[doc("Reset k3s on specified node (removes all k3s data)")]
k3s-reset HOST USER=DEFAULT_USER WAIT="true":
  @{{ if HOST == "" { error("HOST parameter is required") } else { "" } }}
  @echo "WARNING: This will completely reset k3s on {{HOST}}, removing all cluster data!"
  @if [ "{{WAIT}}" = "true" ]; then echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."; sleep 5; fi
  just _run-on {{HOST}} {{USER}} 'sudo systemctl stop k3s || true; sudo systemctl stop k3s-agent || true; sudo rm -rf /var/lib/rancher /etc/rancher; sudo ip addr flush dev lo; sudo ip addr add 127.0.0.1/8 dev lo'
  @echo "k3s reset complete on {{HOST}}"

[group('k3s')]
[doc("Reset entire asgard cluster (odin, loki, thor)")]
k3s-reset-asgard USER=DEFAULT_USER:
  @echo "WARNING: This will completely reset the entire asgard cluster!"
  @echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
  @sleep 5
  just k3s-reset odin {{USER}} false
  just k3s-reset loki {{USER}} false
  just k3s-reset thor {{USER}} false
  @echo "Asgard cluster reset complete"

[group('k3s')]
[doc("Get k3s cluster node status")]
k3s-status HOST USER=DEFAULT_USER:
  @{{ if HOST == "" { error("HOST parameter is required") } else { "" } }}
  just _run-on {{HOST}} {{USER}} 'sudo kubectl get nodes -o wide; echo "---"; sudo kubectl get pods -A'

[group('k3s')]
[doc("View k3s service logs on specified node")]
k3s-logs HOST USER=DEFAULT_USER:
  @{{ if HOST == "" { error("HOST parameter is required") } else { "" } }}
  just _run-on {{HOST}} {{USER}} 'sudo journalctl -u k3s -u k3s-agent -f'
