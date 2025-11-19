# Unified Power State Manager - Core Infrastructure
# Declarative power management for battery and AC modes with pluggable backends
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.powerStateManager;

  # Compose scripts from backend contributions
  # All fragments run in parallel for faster execution
  systemBatteryFragments = attrValues cfg._internal.systemBatteryFragments;
  systemACFragments = attrValues cfg._internal.systemACFragments;
  userBatteryFragments = attrValues cfg._internal.userBatteryFragments;
  userACFragments = attrValues cfg._internal.userACFragments;

  # Helper to wrap each fragment to run in background
  parallelizeFragments = fragments:
    concatMapStringsSep "\n" (fragment: ''
      (
        ${fragment}
      ) &
    '')
    fragments;

  # System service scripts (root context)
  mkSystemBatteryScript = ''
    # Universal settings - Brightness (run in background)
    ${optionalString (cfg.onBattery.brightness != null) ''
      (
        # Set brightness to ${toString cfg.onBattery.brightness}%
        for backlight in /sys/class/backlight/*; do
          if [[ -d "$backlight" ]]; then
            max_brightness=$(cat "$backlight/max_brightness")
            target_brightness=$((max_brightness * ${toString cfg.onBattery.brightness} / 100))
            echo "$target_brightness" > "$backlight/brightness" 2>/dev/null || true
          fi
        done
      ) &
    ''}

    # Backend-contributed system scripts (all run in parallel)
    ${parallelizeFragments systemBatteryFragments}

    # Custom battery script (run in background)
    ${optionalString (cfg.onBattery.extraScript != "") ''
      (
        ${cfg.onBattery.extraScript}
      ) &
    ''}

    # Wait for all parallel operations to complete
    wait
  '';

  mkSystemACScript = ''
    # Universal settings - Brightness (run in background)
    ${optionalString (cfg.onAC.brightness != null) ''
      (
        # Set brightness to ${toString cfg.onAC.brightness}%
        for backlight in /sys/class/backlight/*; do
          if [[ -d "$backlight" ]]; then
            max_brightness=$(cat "$backlight/max_brightness")
            target_brightness=$((max_brightness * ${toString cfg.onAC.brightness} / 100))
            echo "$target_brightness" > "$backlight/brightness" 2>/dev/null || true
          fi
        done
      ) &
    ''}

    # Backend-contributed system scripts (all run in parallel)
    ${parallelizeFragments systemACFragments}

    # Custom AC script (run in background)
    ${optionalString (cfg.onAC.extraScript != "") ''
      (
        ${cfg.onAC.extraScript}
      ) &
    ''}

    # Wait for all parallel operations to complete
    wait
  '';

  # User service scripts (user session context)
  mkUserBatteryScript = ''
    # Backend-contributed user scripts (all run in parallel)
    ${parallelizeFragments userBatteryFragments}

    # Wait for all parallel operations to complete
    wait
  '';

  mkUserACScript = ''
    # Backend-contributed user scripts (all run in parallel)
    ${parallelizeFragments userACFragments}

    # Wait for all parallel operations to complete
    wait
  '';

  # Generic power state switch script with debouncing (DRY)
  mkPowerStateScript = {
    lockFile,
    serviceName,
    batteryScript,
    acScript,
    triggerUserService ? false,
  }: ''
    set -euo pipefail

    LOCKFILE="${lockFile}"
    LOCKFILE_AGE_LIMIT=2

    # Debounce: Exit if another instance is running or ran very recently
    if [ -f "$LOCKFILE" ]; then
      LOCK_AGE=$(($(date +%s) - $(stat -c %Y "$LOCKFILE" 2>/dev/null || echo 0)))
      if [ "$LOCK_AGE" -lt "$LOCKFILE_AGE_LIMIT" ]; then
        echo "[$(date)] ${serviceName}: Debouncing - skipping (last run $LOCK_AGE seconds ago)" | systemd-cat -t power-state-manager -p info
        exit 0
      fi
    fi

    # Create lock file
    echo $$ > "$LOCKFILE"
    trap 'rm -f "$LOCKFILE"' EXIT

    # Detect current power state and run appropriate script
    if [ "$(cat ${cfg.powerSupplyPath} 2>/dev/null || echo 1)" = "0" ]; then
      echo "[$(date)] ${serviceName}: Switching to BATTERY mode" | systemd-cat -t power-state-manager -p info
      ${batteryScript}
    else
      echo "[$(date)] ${serviceName}: Switching to AC mode" | systemd-cat -t power-state-manager -p info
      ${acScript}
    fi

    echo "[$(date)] ${serviceName}: Power state applied" | systemd-cat -t power-state-manager -p info

    ${optionalString triggerUserService ''
      # Trigger user service for session-level changes
      if systemctl --user -M ${config.hostSpec.username}@ is-active graphical-session.target >/dev/null 2>&1; then
        systemctl --user -M ${config.hostSpec.username}@ start power-state-manager-user.service
      fi
    ''}
  '';
in {
  # Auto-discover and import all backend modules
  imports = let
    backendsDir = ./backends;
    backendFiles = builtins.readDir backendsDir;
    nixFiles = filter (name: hasSuffix ".nix" name) (attrNames backendFiles);
  in
    map (file: backendsDir + "/${file}") nixFiles;

  # Core options
  options.services.powerStateManager = {
    enable = mkEnableOption "Automatic power state management for battery and AC modes";

    # Universal settings (work on any system)
    onBattery = {
      brightness = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Screen brightness percentage on battery (0-100). Set to null to not manage.";
        example = 40;
      };

      extraScript = mkOption {
        type = types.lines;
        default = "";
        description = "Additional bash script to run on battery power.";
      };
    };

    onAC = {
      brightness = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Screen brightness percentage on AC power (0-100). Set to null to not manage.";
        example = 100;
      };

      extraScript = mkOption {
        type = types.lines;
        default = "";
        description = "Additional bash script to run on AC power.";
      };
    };

    powerSupplyPath = mkOption {
      type = types.str;
      default = "/sys/class/power_supply/AC0/online";
      description = "Path to AC adapter online status file";
    };

    # Internal options for backends to contribute to
    _internal = {
      # System-level script fragments (run as root)
      systemBatteryFragments = mkOption {
        type = types.attrsOf types.lines;
        default = {};
        internal = true;
        description = ''
          System-level script fragments for battery mode (run as root in parallel).
          Use for: brightness, GPU modes, hardware profiles.
          All fragments execute simultaneously for faster power state transitions.
        '';
      };

      systemACFragments = mkOption {
        type = types.attrsOf types.lines;
        default = {};
        internal = true;
        description = ''
          System-level script fragments for AC mode (run as root in parallel).
          Use for: brightness, GPU modes, hardware profiles.
          All fragments execute simultaneously for faster power state transitions.
        '';
      };

      # User-level script fragments (run in user session)
      userBatteryFragments = mkOption {
        type = types.attrsOf types.lines;
        default = {};
        internal = true;
        description = ''
          User-level script fragments for battery mode (run in user session in parallel).
          Use for: display settings, user preferences, session-specific config.
          All fragments execute simultaneously for faster power state transitions.
        '';
      };

      userACFragments = mkOption {
        type = types.attrsOf types.lines;
        default = {};
        internal = true;
        description = ''
          User-level script fragments for AC mode (run in user session in parallel).
          Use for: display settings, user preferences, session-specific config.
          All fragments execute simultaneously for faster power state transitions.
        '';
      };

      startupDependencies = mkOption {
        type = types.listOf types.str;
        default = [];
        internal = true;
        description = "Startup dependencies contributed by backends";
      };
    };
  };

  # Core implementation
  config = mkIf cfg.enable {
    # System service (runs as root for hardware changes)
    systemd.services."power-state-manager-system" = {
      description = "Power state manager - system level (brightness, GPU, performance)";
      script = mkPowerStateScript {
        lockFile = "/run/power-state-manager.lock";
        serviceName = "System";
        batteryScript = mkSystemBatteryScript;
        acScript = mkSystemACScript;
        triggerUserService = true;
      };
      serviceConfig = {
        Type = "oneshot";
      };
      path = with pkgs; [
        coreutils
        bash
        systemd
      ];
    };

    # User service (runs in user session for display/UI changes)
    systemd.user.services."power-state-manager-user" = {
      description = "Power state manager - user level (display, UI preferences)";
      script = mkPowerStateScript {
        lockFile = "$XDG_RUNTIME_DIR/power-state-manager-user.lock";
        serviceName = "User";
        batteryScript = mkUserBatteryScript;
        acScript = mkUserACScript;
        triggerUserService = false;
      };
      serviceConfig = {
        Type = "oneshot";
      };
      path = with pkgs; [
        coreutils
        bash
        systemd
      ];
    };

    # Udev rule to trigger system service on power changes
    services.udev.extraRules = ''
      # Trigger power state manager on AC adapter change events
      SUBSYSTEM=="power_supply", KERNEL=="AC*", ACTION=="change", TAG+="systemd", ENV{SYSTEMD_WANTS}+="power-state-manager-system.service"
    '';

    # Run on startup (after all backend dependencies)
    systemd.services."power-state-manager-startup" = {
      description = "Set power state on startup";
      wantedBy = ["multi-user.target"];
      after = cfg._internal.startupDependencies;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.systemd.package}/bin/systemctl start power-state-manager-system.service";
      };
    };
  };
}
