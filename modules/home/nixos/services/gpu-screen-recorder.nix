# =============================================================================
# GPU Screen Recorder - Replay Buffer Service
# =============================================================================
#
# Runs gpu-screen-recorder as a systemd user service with an always-on replay
# buffer. Saves the last N seconds of gameplay when triggered.
#
# PREREQUISITES:
#   Add to your NixOS config: programs.gpu-screen-recorder.enable = true
#   This grants the necessary capabilities for promptless recording.
#
# USAGE:
#   services.gpu-screen-recorder = {
#     enable = true;
#     matchMonitorName = "LG ULTRAGEAR";  # Auto-detect by EDID model name
#     # OR
#     display = "DP-3";                   # Use static display identifier
#   };
#
# SAVING REPLAYS:
#   Run `save-gsr-replay` or bind it to a hotkey to save the replay buffer.
#
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.gpu-screen-recorder;

  # ---------------------------------------------------------------------------
  # Scripts
  # ---------------------------------------------------------------------------

  # Resolves monitor model names to DRM connector names (e.g., "LG ULTRAGEAR" -> "DP-3")
  # by reading EDID data from sysfs. This allows stable monitor identification regardless
  # of which physical port the monitor is connected to.
  #
  # Usage:
  #   gsr-find-monitor "LG ULTRAGEAR"  -> prints "DP-3" (first match)
  #   gsr-find-monitor                 -> lists all monitors with their models
  findMonitorScript = pkgs.writeShellApplication {
    name = "gsr-find-monitor";
    runtimeInputs = with pkgs; [binutils-unwrapped gnugrep coreutils];
    text = ''
      target_name="''${1:-}"

      for edid in /sys/class/drm/card*-DP-*/edid; do
        [ -f "$edid" ] || continue

        # Parse connector name from sysfs path: /sys/class/drm/card1-DP-3/edid -> DP-3
        connector="''${edid%/edid}"
        connector="''${connector##*/}"
        dp_name="''${connector#card*-}"

        # Extract model name from EDID binary data
        model=$(strings "$edid" 2>/dev/null | head -5 | tr '\n' ' ')

        if [ -z "$target_name" ]; then
          echo "$dp_name: $model"
        elif echo "$model" | grep -qi "$target_name"; then
          echo "$dp_name"
          exit 0
        fi
      done
    '';
  };

  # Trigger script to save the current replay buffer (sends SIGUSR1 to gsr)
  saveReplayScript = pkgs.writeShellScriptBin "save-gsr-replay" ''
    kill -SIGUSR1 $(${pkgs.procps}/bin/pgrep -f gpu-screen-recorder | head -1)
  '';

  # ---------------------------------------------------------------------------
  # Service Configuration Builders
  # ---------------------------------------------------------------------------

  # Generates shell code to resolve the display name at runtime.
  # Either uses a static name or dynamically looks up by EDID model.
  resolveDisplay =
    if cfg.matchMonitorName != null
    then ''
      DISPLAY_NAME=$(${lib.getExe findMonitorScript} "${cfg.matchMonitorName}")
      if [ -z "$DISPLAY_NAME" ]; then
        echo "gsr error: No monitor found matching '${cfg.matchMonitorName}'"
        echo "Available monitors:"
        ${lib.getExe findMonitorScript} | while read -r line; do echo "  $line"; done
        exit 1
      fi
      echo "Found monitor '${cfg.matchMonitorName}' -> $DISPLAY_NAME"
    ''
    else ''
      DISPLAY_NAME="${cfg.display}"
    '';

  audioArgs = lib.concatMapStringsSep " " (device: "-a '${device}'") cfg.audioDevices;

  startScript = pkgs.writeShellScript "start-gsr-replay" ''
    mkdir -p "${cfg.outputDirectory}"

    ${resolveDisplay}

    exec ${pkgs.gpu-screen-recorder}/bin/gpu-screen-recorder \
      -w "$DISPLAY_NAME" \
      -f ${toString cfg.fps} \
      ${audioArgs} \
      -c mkv \
      -fm vfr \
      -k ${cfg.codec} \
      -q ${cfg.quality} \
      -r ${toString cfg.replayDuration} \
      -o "${cfg.outputDirectory}"
  '';
in {
  # ---------------------------------------------------------------------------
  # Module Options
  # ---------------------------------------------------------------------------

  options.services.gpu-screen-recorder = {
    enable = lib.mkEnableOption "GPU Screen Recorder replay buffer";

    # -- Display Selection --

    display = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "DP-3";
      description = ''
        Static display identifier. Use `screen` for all monitors, `focused` for
        the active monitor, or a specific connector like `DP-3`.
        Mutually exclusive with matchMonitorName.
      '';
    };

    matchMonitorName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "LG ULTRAGEAR";
      description = ''
        Dynamically find the monitor by its EDID model name at service startup.
        Case-insensitive partial match. More stable than static display names
        since it works regardless of which port the monitor is connected to.
        Mutually exclusive with display.
      '';
    };

    # -- Recording Settings --

    fps = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Recording frame rate.";
    };

    quality = lib.mkOption {
      type = lib.types.enum ["medium" "high" "very_high" "ultra"];
      default = "ultra";
      description = "Video encoding quality preset.";
    };

    codec = lib.mkOption {
      type = lib.types.enum ["h264" "hevc" "av1" "vp8" "vp9" "hevc_hdr" "av1_hdr" "hevc_10bit" "av1_10bit"];
      default = "h264";
      description = ''
        Video codec to use. For HDR recording, use "hevc_hdr" or "av1_hdr".
        10-bit options (hevc_10bit, av1_10bit) provide better color depth without HDR metadata.
      '';
    };

    replayDuration = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Replay buffer duration in seconds.";
    };

    # -- Output --

    outputDirectory = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/Videos/Clips";
      description = "Directory where saved replay clips are stored.";
    };

    audioDevices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["default_output|default_input"];
      example = ["default_output" "default_input"];
      description = ''
        Audio devices to record. Use `|` to merge multiple sources into one track.
        Example: "default_output|default_input" captures both system audio and mic.
      '';
    };
  };

  # ---------------------------------------------------------------------------
  # Module Implementation
  # ---------------------------------------------------------------------------

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.display != null || cfg.matchMonitorName != null;
        message = "gpu-screen-recorder: Set either 'display' or 'matchMonitorName'";
      }
    ];

    systemd.user.services.gpu-screen-recorder-replay = {
      Unit = {
        Description = "GPU Screen Recorder Replay Buffer";
        After = ["graphical-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${startScript}";
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install.WantedBy = ["graphical-session.target"];
    };

    home.packages = [saveReplayScript];
  };
}
