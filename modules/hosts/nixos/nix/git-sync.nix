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
    enable = mkEnableOption "Automatic NixOS configuration sync from Git";

    repoPath = mkOption {
      type = types.path;
      default = "${config.hostSpec.home}/nix-config";
      description = "Path to the NixOS configuration git repository";
      example = "/home/user/nix-config";
    };

    branch = mkOption {
      type = types.str;
      default = "main";
      description = "Git branch to track and pull from";
    };

    remote = mkOption {
      type = types.str;
      default = "origin";
      description = "Git remote name to pull from";
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
        When to check for updates (calendar-based, like cron).
        Uses systemd OnCalendar syntax.
        Examples: "daily" (midnight), "03:00" (3 AM daily), "Mon 10:00" (Mondays at 10 AM)
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

    autoRollback = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically rollback to previous generation if rebuild fails";
    };

    user = mkOption {
      type = types.str;
      default = "root";
      description = "User that owns the git repository (for git operations)";
    };

    flakePath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Flake path to use for rebuild (e.g., '.#hostname').
        If null and flake.nix exists in repoPath, automatically uses '.#''${hostname}'.
        If null and no flake.nix exists, uses non-flake rebuild.
      '';
      example = ".#zephy";
    };

    preRebuildHook = mkOption {
      type = types.lines;
      default = "";
      description = "Shell commands to run before rebuilding (e.g., update flake.lock)";
      example = ''
        nix flake update
      '';
    };

    postRebuildHook = mkOption {
      type = types.lines;
      default = "";
      description = "Shell commands to run after successful rebuild";
      example = ''
        echo "Rebuild completed at $(date)" >> /var/log/gitops-rebuild.log
      '';
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

    systemd.services.system-git-sync = let
      sync-script = pkgs.writeShellApplication {
        name = "system-git-sync";
        runtimeInputs = with pkgs;
          [
            git
            nixos-rebuild
            systemd
            coreutils
            gnugrep
            gawk
            sudo
            util-linux
            iputils # For ping command in network check
          ]
          ++ optionals cfg.notifications.enable [
            libnotify
          ];
        text = ''
          set -euo pipefail

          export HOME=/root
          REPO="${cfg.repoPath}"

          # Helper functions
          log() {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
            logger -t system-git-sync "$*"
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

          git_safe() {
            git -c safe.directory="$REPO" "$@"
          }

          git_as_user() {
            sudo -u ${cfg.user} git -c safe.directory="$REPO" "$@"
          }

          cd "$REPO"
          log "Starting GitOps sync check..."

          # Validate git repository
          [ -d .git ] || { log "ERROR: $REPO is not a git repository"; exit 1; }

          ${lib.custom.mkNetworkWaitScript {host = "github.com";}}

          # Fetch and check for changes
          log "Fetching from ${cfg.remote}/${cfg.branch}..."
          git_as_user fetch ${cfg.remote} ${cfg.branch}

          LOCAL=$(git_safe rev-parse HEAD)
          REMOTE=$(git_safe rev-parse ${cfg.remote}/${cfg.branch})

          [ "$LOCAL" = "$REMOTE" ] && { log "No changes detected"; exit 0; }

          log "Changes detected: $LOCAL -> $REMOTE"
          notify -u normal "System Git Sync" "Pulling and rebuilding configuration..."

          # Pull changes
          git_as_user pull ${cfg.remote} ${cfg.branch}

          ${optionalString (cfg.preRebuildHook != "") ''
            # Pre-rebuild hook
            log "Running pre-rebuild hook..."
            ${cfg.preRebuildHook}
          ''}

          # Determine flake path
          ${
            if cfg.flakePath != null
            then ''
              REBUILD_ARGS=(${cfg.rebuildCommand} --flake "$REPO${cfg.flakePath}")
              log "Using flake: $REPO${cfg.flakePath}"
            ''
            else ''
              if [ -f flake.nix ]; then
                REBUILD_ARGS=(${cfg.rebuildCommand} --flake "$REPO#${config.networking.hostName}")
                log "Auto-detected flake: $REPO#${config.networking.hostName}"
              else
                REBUILD_ARGS=(${cfg.rebuildCommand})
                log "Using non-flake rebuild"
              fi
            ''
          }

          # Rebuild system
          log "Running: nixos-rebuild ''${REBUILD_ARGS[*]}"
          CURRENT_GEN=$(nixos-rebuild list-generations | grep current | awk '{print $1}')

          if nixos-rebuild "''${REBUILD_ARGS[@]}"; then
            log "Rebuild successful!"
            notify -u normal "System Git Sync" "Configuration updated successfully!"

            ${optionalString (cfg.postRebuildHook != "") ''
            log "Running post-rebuild hook..."
            ${cfg.postRebuildHook}
          ''}
          else
            log "ERROR: Rebuild failed!"
            notify -u critical "System Git Sync" "Rebuild FAILED! Check logs."

            ${optionalString cfg.autoRollback ''
            log "Auto-rollback to generation $CURRENT_GEN..."
            nixos-rebuild switch --rollback
            log "Rolled back successfully"
            notify -u normal "System Git Sync" "Rolled back to previous configuration"
          ''}

            exit 1
          fi
        '';
      };
    in {
      description = "Automatic NixOS configuration sync from Git";
      after = ["network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${sync-script}/bin/system-git-sync";
      };
    };

    systemd.timers.system-git-sync = {
      description = "Periodically sync and rebuild NixOS configuration from Git";
      wantedBy = ["timers.target"];
      timerConfig =
        {
          Unit = "system-git-sync.service";
          Persistent = true; # Run on boot if missed while system was off
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
