{
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

    autoRollback = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically rollback to previous generation if rebuild fails";
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

    notifications = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable desktop notifications for rebuild events";
      };

      notifyUser = mkOption {
        type = types.nullOr types.str;
        default = "${config.hostSpec.username}";
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
    ];

    systemd.services.nix-remote-rebuild = let
      flake = "${cfg.flakeRef}#${config.networking.hostName}";
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

          ${lib.custom.mkNetworkWaitScript {host = "github.com";}}

          ${optionalString (cfg.preRebuildHook != "") ''
            log "Running pre-rebuild hook..."
            ${cfg.preRebuildHook}
          ''}

          log "Rebuilding from ${flake}..."
          notify -u normal "NixOS Remote Rebuild" "Rebuilding from ${flake}..."

          CURRENT_GEN=$(nixos-rebuild list-generations | grep current | awk '{print $1}' || echo "unknown")

          REBUILD_LOG=$(mktemp /tmp/nix-rebuild-XXXXXX.log)
          trap 'rm -f "$REBUILD_LOG"' EXIT

          if nixos-rebuild ${cfg.rebuildCommand} --flake "${flake}" 2>&1 | tee "$REBUILD_LOG"; then
            log "Rebuild successful!"
            notify -u normal "NixOS Remote Rebuild" "Configuration updated successfully!"

            ${optionalString (cfg.postRebuildHook != "") ''
            log "Running post-rebuild hook..."
            ${cfg.postRebuildHook}
          ''}

            ${optionalString cfg.rebootAfterBuild (
            if cfg.notifications.enable
            then ''
              log "Scheduling reboot in 2 minutes..."
              notify -u critical "NixOS Remote Rebuild" "Configuration updated. Rebooting in 2 minutes. Run 'sudo shutdown -c' to cancel."
              shutdown --reboot +2 "NixOS remote rebuild complete. Rebooting in 2 minutes. Run 'sudo shutdown -c' to cancel."
            ''
            else ''
              log "Rebooting now..."
              systemctl reboot
            ''
          )}
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

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${rebuild-script}/bin/nix-remote-rebuild";
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
