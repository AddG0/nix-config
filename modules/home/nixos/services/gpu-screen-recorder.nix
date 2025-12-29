# GPU Screen Recorder replay buffer service
#
# NOTE: This module runs gpu-screen-recorder as a user service.
# You also need `programs.gpu-screen-recorder.enable = true` in your
# NixOS config to set up the required capabilities for promptless recording.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.gpu-screen-recorder;

  saveReplayScript = pkgs.writeShellScriptBin "save-gsr-replay" ''
    kill -SIGUSR1 $(pgrep -f gpu-screen-recorder | head -1)
  '';
in {
  options.services.gpu-screen-recorder = {
    enable = lib.mkEnableOption "GPU Screen Recorder replay buffer";

    display = lib.mkOption {
      type = lib.types.str;
      default = "screen";
      example = "DP-5";
      description = "The display to record (monitor name, screen, focused, portal, or region)";
    };

    fps = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Frame rate to record at";
    };

    quality = lib.mkOption {
      type = lib.types.enum ["medium" "high" "very_high" "ultra"];
      default = "ultra";
      description = "Video quality";
    };

    replayDuration = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Replay buffer size in seconds";
    };

    outputDirectory = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/Videos/Clips";
      description = "Directory to save replay clips";
    };

    audioDevices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["default_output|default_input"];
      example = ["default_output|default_input"];
      description = "List of audio devices to record. Use | to merge multiple sources into one track.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.gpu-screen-recorder-replay = {
      Unit = {
        Description = "GPU Screen Recorder Replay Buffer";
        After = ["graphical-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "start-gsr-replay" ''
          #!/usr/bin/env bash
          VIDEOS_DIR="${cfg.outputDirectory}"
          mkdir -p "$VIDEOS_DIR"

          exec ${pkgs.gpu-screen-recorder}/bin/gpu-screen-recorder \
            -w ${cfg.display} \
            -f ${toString cfg.fps} \
            ${lib.concatMapStringsSep " " (device: "-a '${device}'") cfg.audioDevices} \
            -c mp4 \
            -q ${cfg.quality} \
            -r ${toString cfg.replayDuration} \
            -o "$VIDEOS_DIR"
        ''}";
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };

    home.packages = [saveReplayScript];
  };
}
