# KDE Plasma display management backend
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.powerStateManager;
  kdeCfg = cfg.kde;

  # Helper to build kscreen-doctor commands with mode detection
  # Runs in user session context, so no need for runuser or environment setup
  mkRefreshRateScript = outputs: refreshRate: modeNum:
    let
      # If mode number is provided, use it directly
      # Otherwise, try to auto-detect by parsing kscreen-doctor output
      modeDetectionScript = if modeNum != null then ''
        MODE_NUM=${toString modeNum}
      '' else ''
        # Auto-detect mode number for ${toString refreshRate}Hz
        # Look for refresh rate with decimals (e.g., 60.03, 165.04)
        # Strip ANSI color codes first to avoid pattern matching issues
        MODE_NUM=$(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor --outputs 2>&1 | \
          sed 's/\x1b\[[0-9;]*m//g' | \
          grep -A 20 "${head outputs}" | \
          grep "Modes:" | \
          grep -o '[0-9]\+:[^@]*@${toString refreshRate}\.[0-9]*' | \
          head -n 1 | \
          cut -d: -f1)

        if [ -z "$MODE_NUM" ]; then
          echo "Warning: Could not auto-detect mode for ${toString refreshRate}Hz, skipping refresh rate change" >&2
          exit 0
        fi
      '';

      setModeCommands = concatMapStringsSep "\n" (output:
        ''${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.${output}.mode.$MODE_NUM 2>&1 || echo "Warning: Failed to set refresh rate for ${output}" >&2''
      ) outputs;
    in ''
      ${modeDetectionScript}
      ${setModeCommands}
    '';
in {
  options.services.powerStateManager.kde = {
    enable = mkEnableOption "KDE Plasma display management backend";

    outputs = mkOption {
      type = types.listOf types.str;
      default = ["eDP-1"];
      description = "List of KDE display output names to manage refresh rates for.";
      example = ["eDP-1" "DP-1"];
    };

    onBattery = {
      refreshRate = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Display refresh rate on battery (Hz). Requires KDE backend.";
        example = 60;
      };

      modeNumber = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          KDE mode number for battery refresh rate.
          If null (default), the mode will be auto-detected from kscreen-doctor output.
          Set explicitly if auto-detection fails. Use 'kscreen-doctor --outputs' to find mode numbers.
        '';
        example = 2;
      };
    };

    onAC = {
      refreshRate = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Display refresh rate on AC (Hz). Requires KDE backend.";
        example = 165;
      };

      modeNumber = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          KDE mode number for AC refresh rate.
          If null (default), the mode will be auto-detected from kscreen-doctor output.
          Set explicitly if auto-detection fails. Use 'kscreen-doctor --outputs' to find mode numbers.
        '';
        example = 1;
      };
    };
  };

  config = mkIf (cfg.enable && kdeCfg.enable) {
    # Contribute to user battery script (runs in parallel with other backends)
    services.powerStateManager._internal.userBatteryFragments = mkIf (kdeCfg.onBattery.refreshRate != null) {
      "kde" = let
        modeScript = mkRefreshRateScript kdeCfg.outputs kdeCfg.onBattery.refreshRate kdeCfg.onBattery.modeNumber;
      in ''
        # KDE: Set refresh rate to ${toString kdeCfg.onBattery.refreshRate}Hz${optionalString (kdeCfg.onBattery.modeNumber != null) " (mode ${toString kdeCfg.onBattery.modeNumber})"}
        ${modeScript}
      '';
    };

    # Contribute to user AC script (runs in parallel with other backends)
    services.powerStateManager._internal.userACFragments = mkIf (kdeCfg.onAC.refreshRate != null) {
      "kde" = let
        modeScript = mkRefreshRateScript kdeCfg.outputs kdeCfg.onAC.refreshRate kdeCfg.onAC.modeNumber;
      in ''
        # KDE: Set refresh rate to ${toString kdeCfg.onAC.refreshRate}Hz${optionalString (kdeCfg.onAC.modeNumber != null) " (mode ${toString kdeCfg.onAC.modeNumber})"}
        ${modeScript}
      '';
    };

    # Validation
    assertions = [
      {
        assertion = kdeCfg.onBattery.refreshRate != null -> kdeCfg.onAC.refreshRate != null;
        message = "If kde.onBattery.refreshRate is set, kde.onAC.refreshRate should also be set";
      }
      {
        assertion = kdeCfg.outputs != [];
        message = "kde.outputs must not be empty";
      }
    ];

    # Warnings
    warnings = optional
      (!config.services.desktopManager.plasma6.enable)
      "powerStateManager.kde.enable is true but KDE Plasma doesn't appear to be enabled";
  };
}
