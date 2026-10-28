{customLib, ...}: {
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nix.git-sync;
in {
  options.nix.git-sync = {
    enable = mkEnableOption "Automatic NixOS rebuild from a remote flake";

    flakeRef = mkOption {
      type = types.str;
      default = "github:AddG0/nix-config";
      description = ''
        Remote flake reference passed to `nixos-rebuild --flake`.
        The hostname is appended automatically (e.g. `github:user/repo#hostname`).
      '';
      example = "github:AddG0/nix-config";
    };

    interval = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        How often to check for updates (relative to last run).
        Examples: "30min", "1h", "1day"
        Mutually exclusive with schedule.
      '';
      example = "30min";
    };

    schedule = mkOption {
      type = types.nullOr types.str;
      default = "03:00";
      description = ''
        When to rebuild (calendar-based).
        Uses systemd OnCalendar syntax.
        Mutually exclusive with interval.
      '';
      example = "Mon 10:00";
    };

    rebuildCommand = mkOption {
      type = types.enum ["switch" "boot" "test"];
      default = "switch";
      description = ''
        NixOS rebuild command to use:
        - switch: Apply changes immediately and make them persistent
        - boot: Apply changes on next boot
        - test: Apply changes temporarily (lost on reboot)
      '';
    };

    rebootAfterBuild = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Reboot after a successful rebuild.
        Useful with rebuildCommand = "boot" to apply changes via a clean reboot.
      '';
    };

    rebootIfNeeded = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Reboot after a successful rebuild only when the kernel, initrd or kernel
        modules changed — the three things `nixos-rebuild switch` cannot activate
        under the running system.

        Compares `/run/booted-system` against `/nix/var/nix/profiles/system`, so a
        nixpkgs bump that leaves the kernel alone does not reboot, and a kernel
        patch inside an unchanged version string does.

        Mutually exclusive with rebootAfterBuild.
      '';
    };

    autoRollback = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically rollback to previous generation if rebuild fails";
    };

    checkRemoteNewer = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Skip the rebuild when the remote flake is unchanged since the last
        successful rebuild, or when the running system is ahead of it.

        Compares the remote's `locked.narHash` from `nix flake metadata --refresh`
        against the one recorded after the last successful rebuild. A hand deploy
        never updates that record, so the running system's
        `system.configurationRevision` is also checked: the rebuild is skipped
        unless the remote's history contains that commit and moves past it. A
        deploy from an unpushed commit, or uncommitted work on top of the remote's
        tip, stays until the remote catches up; uncommitted work on an older base
        is replaced once the remote moves on.
        A host with no recorded rebuild or revision (e.g. freshly booted from an
        image) rebuilds once. Runs as a systemd `ExecCondition`, so the unit is
        marked "skipped" (not failed) when no update is needed, and failed when
        the remote's history cannot be fetched.
      '';
    };

    preRebuildHook = mkOption {
      type = types.lines;
      default = "";
      description = "Shell commands to run before rebuilding";
    };

    postRebuildHook = mkOption {
      type = types.lines;
      default = "";
      description = "Shell commands to run after successful rebuild";
    };

    allowedSigners = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        SSH public keys allowed to sign the deployed commit. When non-empty, the
        rebuild refuses any locked revision not signed by one of them, so pushing
        to the remote alone is not enough to get root on the host.
      '';
      example = ["ssh-ed25519 AAAA..."];
    };

    sshKey = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to SSH private key for fetching private flake inputs (e.g. nix-secrets)";
      example = "/root/.ssh/id_ed25519";
    };

    notifications = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable desktop notifications for rebuild events";
      };

      notifyUser = mkOption {
        type = types.nullOr types.str;
        default = "${config.hostSpec.primaryUsername}";
        description = "User to send notifications to (required if notifications.enable is true)";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.notifications.enable -> cfg.notifications.notifyUser != null;
        message = "nix.git-sync.notifications.notifyUser must be set when notifications are enabled";
      }
      {
        assertion = (cfg.interval != null) != (cfg.schedule != null);
        message = "nix.git-sync: exactly one of 'interval' or 'schedule' must be set";
      }
      {
        # rebootAfterBuild fires first, so a host setting both silently gets always-reboot.
        assertion = !(cfg.rebootAfterBuild && cfg.rebootIfNeeded);
        message = "nix.git-sync: set at most one of 'rebootAfterBuild' or 'rebootIfNeeded'";
      }
    ];

    systemd.services.nix-remote-rebuild = let
      flake = "${cfg.flakeRef}#${config.networking.hostName}";
      lastBuiltFile = "/var/lib/nix-remote-rebuild/last-built-narhash";
      allowedSignersFile = pkgs.writeText "git-sync-allowed-signers" (
        concatMapStrings (key: "git-sync namespaces=\"git\" ${key}\n") cfg.allowedSigners
      );
      check-newer-script = pkgs.writeShellApplication {
        name = "nix-remote-rebuild-check-newer";
        runtimeInputs = with pkgs; [nix jq coreutils git openssh];
        text = ''
          set -euo pipefail

          ${optionalString (cfg.sshKey != null) ''
            export GIT_SSH_COMMAND="ssh -i ${cfg.sshKey} -o StrictHostKeyChecking=accept-new"
          ''}

          metadata=$(nix flake metadata "${cfg.flakeRef}" --refresh --json)
          remote=$(jq -r '.locked.narHash' <<<"$metadata")
          remote_rev=$(jq -r '.locked.rev // empty' <<<"$metadata")

          if [ -f "${lastBuiltFile}" ] && [ "$(cat "${lastBuiltFile}")" = "$remote" ]; then
            echo "Remote flake unchanged since last rebuild ($remote); skipping."
            exit 1
          fi

          # Exits 1 for a system built without a revision: then only the narHash above decides.
          running=$(/run/current-system/sw/bin/nixos-version --configuration-revision 2>/dev/null) || running=""
          base=''${running%-dirty}
          if [ -n "$base" ] && [ -n "$remote_rev" ]; then
            if [ "$base" = "$remote_rev" ]; then
              echo "Running $running, built from the remote's current commit; skipping."
              exit 1
            fi
            case "$(jq -r '.locked.type' <<<"$metadata")" in
              github) git_url="https://github.com/$(jq -r '.locked.owner + "/" + .locked.repo' <<<"$metadata").git" ;;
              *) git_url=$(jq -r '.locked.url // empty' <<<"$metadata") ;;
            esac
            history=$(mktemp -d)
            trap 'rm -rf "$history"' EXIT
            git -C "$history" init -q
            # 255 fails the unit: a history it cannot read must not pass for "behind".
            git -C "$history" fetch -q --filter=blob:none "$git_url" "$remote_rev" || {
              echo "Cannot fetch $remote_rev from $git_url to compare with running $running."
              exit 255
            }
            if ! git -C "$history" merge-base --is-ancestor "$base" "$remote_rev" 2>/dev/null; then
              echo "Running $running is not in the remote's history (a hand deploy from an unpushed commit); skipping."
              exit 1
            fi
          fi
          echo "Remote flake changed ($remote_rev) and contains running ''${running:-unknown}; proceeding with rebuild."
          exit 0
        '';
      };
      rebootAction =
        if cfg.notifications.enable
        then ''
          log "Scheduling reboot in 2 minutes..."
          notify -u critical "NixOS Remote Rebuild" "Configuration updated. Rebooting in 2 minutes. Run 'sudo shutdown -c' to cancel."
          shutdown --reboot +2 "NixOS remote rebuild complete. Rebooting in 2 minutes. Run 'sudo shutdown -c' to cancel."
        ''
        else ''
          log "Rebooting now..."
          systemctl reboot
        '';
      rebuild-script = pkgs.writeShellApplication {
        name = "nix-remote-rebuild";
        runtimeInputs = with pkgs;
          [
            nixos-rebuild
            systemd
            coreutils
            gawk
            gnugrep
            iputils
            util-linux
            git
            openssh
            nix
            jq
          ]
          ++ optionals cfg.notifications.enable [
            libnotify
            sudo
          ];
        text = ''
          set -euo pipefail

          log() {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
            logger -t nix-remote-rebuild -- "$*"
          }

          notify() {
            ${
            if cfg.notifications.enable
            then ''
              for session in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
                user=$(loginctl show-session "$session" -p Name --value)
                if [ "$user" = "${cfg.notifications.notifyUser}" ]; then
                  uid=$(loginctl show-session "$session" -p User --value)
                  display=$(loginctl show-session "$session" -p Display --value || echo ":0")
                  sudo -u "${cfg.notifications.notifyUser}" \
                    DISPLAY="$display" \
                    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
                    notify-send "$@"
                  break
                fi
              done
            ''
            else ''
              :  # Notifications disabled
            ''
          }
          }

          ${optionalString (cfg.sshKey != null) ''
            export GIT_SSH_COMMAND="ssh -i ${cfg.sshKey} -o StrictHostKeyChecking=accept-new"
          ''}

          ${(customLib.mkNetworkWaitScript {host = "github.com";})}

          ${optionalString (cfg.preRebuildHook != "") ''
            log "Running pre-rebuild hook..."
            ${cfg.preRebuildHook}
          ''}

          # Build the exact locked revision so the recorded hash matches what was deployed.
          METADATA=$(nix flake metadata "${cfg.flakeRef}" --refresh --json)
          LOCKED_URL=$(jq -r '.url' <<<"$METADATA")
          LOCKED_NARHASH=$(jq -r '.locked.narHash' <<<"$METADATA")

          ${optionalString (cfg.allowedSigners != []) ''
            LOCKED_REV=$(jq -r '.locked.rev // empty' <<<"$METADATA")
            case "$(jq -r '.locked.type' <<<"$METADATA")" in
              github) GIT_URL="https://github.com/$(jq -r '.locked.owner + "/" + .locked.repo' <<<"$METADATA").git" ;;
              git) GIT_URL=$(jq -r '.locked.url' <<<"$METADATA") ;;
              *) GIT_URL="" ;;
            esac
            if [ -z "$LOCKED_REV" ] || [ -z "$GIT_URL" ]; then
              log "ERROR: cannot verify the signature of $LOCKED_URL (no git revision); refusing to rebuild."
              notify -u critical "NixOS Remote Rebuild" "Refused unverifiable flake $LOCKED_URL"
              exit 1
            fi

            VERIFY_DIR=$(mktemp -d)
            git -C "$VERIFY_DIR" init -q
            if ! git -C "$VERIFY_DIR" fetch -q --depth=1 "$GIT_URL" "$LOCKED_REV" ||
              ! git -C "$VERIFY_DIR" -c gpg.ssh.allowedSignersFile=${allowedSignersFile} verify-commit "$LOCKED_REV"; then
              rm -rf "$VERIFY_DIR"
              log "ERROR: $LOCKED_REV from $GIT_URL is not signed by an allowed key; refusing to rebuild."
              notify -u critical "NixOS Remote Rebuild" "Refused unsigned commit $LOCKED_REV"
              exit 1
            fi
            rm -rf "$VERIFY_DIR"
            log "Verified signature on $LOCKED_REV."
          ''}

          log "Rebuilding from $LOCKED_URL#${config.networking.hostName}..."
          notify -u normal "NixOS Remote Rebuild" "Rebuilding from ${flake}..."

          CURRENT_GEN=$(nixos-rebuild list-generations | grep current | awk '{print $1}' || echo "unknown")

          REBUILD_LOG=$(mktemp /tmp/nix-rebuild-XXXXXX.log)
          trap 'rm -f "$REBUILD_LOG"' EXIT

          if nixos-rebuild ${cfg.rebuildCommand} --flake "$LOCKED_URL#${config.networking.hostName}" 2>&1 | tee "$REBUILD_LOG"; then
            log "Rebuild successful!"
            echo "$LOCKED_NARHASH" > "${lastBuiltFile}"
            notify -u normal "NixOS Remote Rebuild" "Configuration updated successfully!"

            ${optionalString (cfg.postRebuildHook != "") ''
            log "Running post-rebuild hook..."
            ${cfg.postRebuildHook}
          ''}

            ${optionalString cfg.rebootAfterBuild rebootAction}

            ${optionalString cfg.rebootIfNeeded ''
            # switch activates everything but these three under the running kernel.
            needs_reboot=0
            for f in kernel initrd kernel-modules; do
              [ "$(readlink -f "/run/booted-system/$f")" = "$(readlink -f "/nix/var/nix/profiles/system/$f")" ] || needs_reboot=1
            done
            if [ "$needs_reboot" = 1 ]; then
              log "Kernel, initrd or modules changed."
            ${rebootAction}
            else
              log "Userspace-only update; no reboot needed."
            fi
          ''}
          else
            REBUILD_EXIT="''${PIPESTATUS[0]}"
            log "ERROR: Rebuild failed (exit code $REBUILD_EXIT)!"
            # Log last 30 lines of output for diagnosis
            log "--- rebuild output (last 30 lines) ---"
            tail -30 "$REBUILD_LOG" | while IFS= read -r line; do
              log "  $line"
            done
            log "--- end rebuild output ---"
            notify -u critical "NixOS Remote Rebuild" "Rebuild FAILED! Check logs."

            ${optionalString cfg.autoRollback ''
            log "Auto-rollback to generation $CURRENT_GEN..."
            nixos-rebuild switch --rollback
            log "Rolled back successfully"
            notify -u normal "NixOS Remote Rebuild" "Rolled back to previous configuration"
          ''}

            exit 1
          fi
        '';
      };
    in {
      description = "Automatic NixOS rebuild from remote flake";
      after = ["network-online.target"];
      wants = ["network-online.target"];

      # Prevent nixos-rebuild switch from killing this service mid-run
      restartIfChanged = false;
      stopIfChanged = false;

      serviceConfig =
        {
          Type = "oneshot";
          StateDirectory = "nix-remote-rebuild";
          ExecStart = "${rebuild-script}/bin/nix-remote-rebuild";
        }
        // optionalAttrs cfg.checkRemoteNewer {
          ExecCondition = "${check-newer-script}/bin/nix-remote-rebuild-check-newer";
        };
    };

    systemd.timers.nix-remote-rebuild = {
      description = "Periodically rebuild NixOS from remote flake";
      wantedBy = ["timers.target"];
      timerConfig =
        {
          Unit = "nix-remote-rebuild.service";
          Persistent = true;
        }
        // (
          if cfg.schedule != null
          then {
            OnCalendar = cfg.schedule;
          }
          else {
            OnBootSec = "5min";
            OnUnitActiveSec = cfg.interval;
          }
        );
    };
  };
}
