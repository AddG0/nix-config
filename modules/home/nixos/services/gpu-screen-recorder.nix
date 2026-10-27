# GPU Screen Recorder - Replay Buffer Service
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
#     # OR
#     display = "portal";                 # Use xdg-desktop-portal (converts HDR to SDR)
#   };
#
#   When display = "portal" *and* matchMonitorName is set, the module wires
#   xdph's `custom_picker_binary` to a non-interactive picker that auto-selects
#   the configured monitor whenever GSR requests a fresh portal session. Other
#   screencast clients (browser, Slack, OBS) fall through to the normal
#   interactive hyprland-share-picker dialog.
#
# SAVING REPLAYS:
#   Run `save-gsr-replay` or bind it to a hotkey to save the replay buffer.
#   `postSaveScript` hooks an executable to run on each saved file; it may move
#   the clip and prints the clip's final path. HDR10 clips (from an HDR codec)
#   are then handled per `hdrClips`: converted to SDR by default, since
#   Discord, phones and most browsers show HDR10 washed out.
#
# LIFECYCLE (see docs/adr/0004-gsr-lifecycle-in-systemd.md):
#   GSR is the unit's main process; systemd restarts it and SIGKILLs a hung
#   stop. With matchMonitorName, ExecCondition skips starts while the monitor
#   is disconnected and, on Hyprland, gsr-monitor-gate starts/stops the unit
#   on monitor events. In portal mode, gsr-health.timer restarts GSR when its
#   video stream has no pipewire link.
#
# AFTER REBUILDS:
#   xdph reads `~/.config/hypr/xdph.conf` only at startup. Since the smart
#   picker's nix store path changes on every rebuild, restart xdph for the
#   new picker to take effect (or reboot):
#     systemctl --user restart xdg-desktop-portal-hyprland.service
#   Changes to matchMonitorName itself are handled automatically by a
#   home-manager activation hook: it clears the cached portal token and
#   restarts the replay service when the configured monitor changes.
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
  # by reading EDID data from sysfs. Stable across physical port changes and
  # works for any connector type (DP, HDMI, eDP, VGA, ...).
  #
  # Usage:
  #   gsr-find-monitor "LG ULTRAGEAR"  -> prints "DP-3" (first match)
  #   gsr-find-monitor                 -> lists all monitors with their models
  findMonitorScript = pkgs.writeShellApplication {
    name = "gsr-find-monitor";
    runtimeInputs = with pkgs; [binutils-unwrapped gnugrep coreutils];
    text = ''
      target_name="''${1:-}"

      for edid in /sys/class/drm/card*-*/edid; do
        # Sysfs reports apparent size as 0 even when the file has content,
        # so use -f (exists) rather than -s (non-empty).
        [ -f "$edid" ] || continue

        # Parse connector name from sysfs path: /sys/class/drm/card1-DP-3/edid -> DP-3
        connector="''${edid%/edid}"
        connector="''${connector##*/}"
        name="''${connector#card*-}"

        # Extract model name from EDID binary data
        model=$(strings "$edid" 2>/dev/null | head -5 | tr '\n' ' ')

        if [ -z "$target_name" ]; then
          echo "$name: $model"
        elif echo "$model" | grep -qi "$target_name"; then
          echo "$name"
          exit 0
        fi
      done
    '';
  };

  # Tells gpu-screen-recorder to flush its replay buffer to disk (SIGUSR1).
  #
  # Optionally sleeps for postRecordSeconds first so the saved clip includes
  # that many seconds *after* the button press — GSR keeps filling the rolling
  # buffer during the sleep, so by the time SIGUSR1 fires the trailing tail is
  # already captured. Accepts an override as the first CLI arg.
  saveReplayScript = pkgs.writeShellApplication {
    name = "save-gsr-replay";
    runtimeInputs = with pkgs; [procps coreutils];
    text = ''
      delay="''${1:-${toString cfg.postRecordSeconds}}"

      # Sleep first, then resolve pid: GSR may exit during the wait (monitor
      # unplug, compositor disable, etc.), so the only pid worth signaling is
      # the one alive *after* the tail delay.
      [ "$delay" -gt 0 ] 2>/dev/null && sleep "$delay"

      pid=$(pidof gpu-screen-recorder || true)
      if [ -z "$pid" ]; then
        echo "save-gsr-replay: gpu-screen-recorder is not running" >&2
        exit 1
      fi

      kill -SIGUSR1 "$pid"
    '';
  };

  # Drops GSR's cached restore_token and restarts the replay service, forcing
  # the smart picker to re-resolve the configured monitor on the next start.
  # Use after changing matchMonitorName, plugging/unplugging monitors, or any
  # time the active capture should be redirected.
  repickMonitorScript = pkgs.writeShellApplication {
    name = "gsr-repick-monitor";
    runtimeInputs = with pkgs; [systemd coreutils];
    text = ''
      systemctl --user stop gpu-screen-recorder-replay.service
      rm -f "$HOME/.config/gpu-screen-recorder/restore_token"
      systemctl --user start gpu-screen-recorder-replay.service

      # Wait briefly for the smart picker to auto-resolve and GSR to write
      # the new token. Absence after the wait means the configured monitor
      # wasn't connected — the smart picker fell through to the interactive
      # dialog (which the user must complete manually).
      for _ in 1 2 3 4 5; do
        [ -s "$HOME/.config/gpu-screen-recorder/restore_token" ] && break
        sleep 1
      done

      if [ -s "$HOME/.config/gpu-screen-recorder/restore_token" ]; then
        echo "GSR restarted; smart picker auto-selected the configured monitor."
      else
        echo "GSR restarted, but auto-pick did not complete — the configured monitor may not be connected. Check the share-picker dialog or 'systemctl --user status gpu-screen-recorder-replay.service'." >&2
        exit 1
      fi
    '';
  };

  # A non-interactive replacement for hyprland-share-picker. When invoked
  # during a GSR fresh-portal-session (GSR running but no cached restore
  # token), auto-prints the [SELECTION] line for the configured monitor and
  # exits. For any other screencast client (browser, Slack, OBS, …), execs
  # the real hyprland-share-picker so the user gets the normal dialog.
  #
  # Protocol (per xdph's custom_picker_binary contract):
  #   argv: optionally `--allow-token`
  #   stdout: `[SELECTION]<r?>/screen:<connector>\n`
  smartPickerScript = pkgs.writeShellApplication {
    name = "gsr-smart-picker";
    runtimeInputs = with pkgs; [findMonitorScript videoStreamScript procps coreutils xdg-desktop-portal-hyprland];
    text = ''
      allow_token=""
      for arg in "$@"; do
        [ "$arg" = "--allow-token" ] && allow_token="r"
      done

      # This invocation is GSR's if GSR is running without a linked video
      # stream: a streaming GSR has one, and GSR re-opening its session (at
      # start, or its own restart after the monitor turns off) does not. Any
      # other client (Slack, browser, OBS) gets the real interactive picker.
      #
      # Use `pidof` (matches binary name) rather than `pgrep -x` (matches only
      # the 15-char kernel COMM, which truncates "gpu-screen-recorder").
      gsr_is_requesting=no
      if gsr_pid=$(pidof -s gpu-screen-recorder); then
        case $(gsr-video-stream "$gsr_pid" || echo unknown) in
          unlinked | no-video-node) gsr_is_requesting=yes ;;
        esac
      fi

      if [ "$gsr_is_requesting" = "yes" ]; then
        dp=$(gsr-find-monitor ${lib.escapeShellArg (
        if cfg.matchMonitorName == null
        then ""
        else cfg.matchMonitorName
      )})
        if [ -n "$dp" ]; then
          printf '[SELECTION]%s/screen:%s\n' "$allow_token" "$dp"
          exit 0
        fi
        # Configured monitor isn't connected. Don't spawn an interactive
        # dialog — just fail so xdph rejects the session and GSR exits;
        # ExecCondition and the monitor gate hold it until the monitor returns.
        echo "gsr-smart-picker: configured monitor not connected — failing without selection" >&2
        exit 1
      fi

      exec hyprland-share-picker "$@"
    '';
  };

  # ---------------------------------------------------------------------------
  # Service Configuration Builders
  # ---------------------------------------------------------------------------

  usePortal = cfg.display == "portal";
  enableAutoPicker = usePortal && cfg.matchMonitorName != null;

  # Shell snippet that sets DISPLAY_NAME for the GSR command line:
  #   - portal mode → "portal"
  #   - matchMonitorName set → resolved DRM connector from EDID
  #   - static display → that connector verbatim

  resolveDisplay =
    if usePortal
    then ''DISPLAY_NAME="portal"''
    else if cfg.matchMonitorName != null
    then ''
      DISPLAY_NAME=$(gsr-find-monitor ${lib.escapeShellArg cfg.matchMonitorName})
      if [ -z "$DISPLAY_NAME" ]; then
        echo "gsr error: no monitor matches '${cfg.matchMonitorName}'. Available:" >&2
        gsr-find-monitor >&2
        exit 1
      fi
      echo "Resolved '${cfg.matchMonitorName}' -> $DISPLAY_NAME"
    ''
    else ''DISPLAY_NAME="${cfg.display}"'';

  # ExecStartPre: block until xdg-desktop-portal's ScreenCast interface is
  # responsive on dbus. Real readiness check (no polling sleep), returns
  # immediately on a warm system.
  waitForPortalScript = pkgs.writeShellApplication {
    name = "gsr-wait-for-portal";
    runtimeInputs = with pkgs; [glib systemd];
    text = ''
      gdbus wait --session --timeout 30 org.freedesktop.portal.Desktop || {
        echo "gsr-wait-for-portal: portal dbus name did not appear within 30s" >&2
        exit 1
      }
      # The bus name can be claimed before xdph finishes wiring up its
      # backend, so one short introspect confirms the interface is live.
      for _ in 1 2 3 4 5; do
        busctl --user introspect \
          org.freedesktop.portal.Desktop \
          /org/freedesktop/portal/desktop \
          org.freedesktop.portal.ScreenCast >/dev/null 2>&1 && exit 0
        sleep 1
      done
      echo "gsr-wait-for-portal: ScreenCast interface not ready" >&2
      exit 1
    '';
  };

  audioArgs = lib.concatMapStringsSep " " (device: "-a '${device}'") cfg.audioDevices;

  # GSR's portal video node carries no process id, only its pipewire client's id.
  videoLinkedFilter = pkgs.writeText "gsr-video-linked.jq" ''
    (map(select(.type == "PipeWire:Interface:Client" and .info.props["application.process.id"] == $pid) | .id)) as $clients
    | (map(select(.type == "PipeWire:Interface:Node" and .info.props["media.class"] == "Stream/Input/Video"
                  and (.info.props["client.id"] as $c | $clients | index($c)))) | map(.id)) as $nodes
    | if ($nodes | length) == 0 then "no-video-node"
      elif any(.[]; .type == "PipeWire:Interface:Link" and (.info["input-node-id"] as $i | $nodes | index($i))) then "linked"
      else "unlinked" end
  '';

  # Prints linked / unlinked / no-video-node for a GSR pid; exits non-zero if pipewire can't be queried.
  videoStreamScript = pkgs.writeShellApplication {
    name = "gsr-video-stream";
    runtimeInputs = with pkgs; [pipewire jq];
    text = ''
      dump=$(pw-dump) || { echo "gsr-video-stream: pw-dump failed" >&2; exit 1; }
      jq -r --argjson pid "$1" -f ${videoLinkedFilter} <<<"$dump"
    '';
  };

  # Resolves the capture target and execs GSR, so GSR is the unit's main
  # process and systemd owns restarts and stop escalation.
  # Runs on every save: the user's postSaveScript (which may move the clip),
  # then the HDR10 handling chosen by hdrClips, on the clip's final path.
  postSavePipeline = pkgs.writeShellApplication {
    name = "gsr-post-save";
    # ffmpeg-full: the plain build lacks the libplacebo GPU tone-mapper.
    runtimeInputs = with pkgs; [coreutils ffmpeg-full];
    text = ''
      clip="''${1:?usage: gsr-post-save <filepath> [type]}"

      ${lib.optionalString (cfg.postSaveScript != null) ''
        if moved=$(${lib.getExe cfg.postSaveScript} "$@"); then
          [ -z "$moved" ] || clip=''${moved##*$'\n'}
        else
          echo "gsr-post-save: postSaveScript failed for $clip" >&2
        fi
      ''}
      ${lib.optionalString (cfg.hdrClips != "hdr") ''
        [ -f "$clip" ] || exit 0
        [ "$(ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer \
          -of default=nw=1:nk=1 "$clip")" = smpte2084 ] || exit 0

        # The original is touched only once the SDR copy is fully written.
        sdr="''${clip%.*}.sdr-tmp.''${clip##*.}"
        if ffmpeg -hide_banner -loglevel error -y -i "$clip" -map 0 \
          -vf "libplacebo=tonemapping=bt.2390:colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv:format=yuv420p" \
          -c:v h264_nvenc -preset p5 -cq 19 -c:a copy \
          -color_primaries bt709 -color_trc bt709 -colorspace bt709 -movflags +faststart "$sdr"; then
          ${lib.optionalString (cfg.hdrClips == "both") ''mv -- "$clip" "''${clip%.*}.hdr.''${clip##*.}"''}
          mv -f -- "$sdr" "$clip"
          echo "gsr-post-save: converted to SDR: $clip"
        else
          rm -f -- "$sdr"
          echo "gsr-post-save: SDR conversion failed, kept the HDR10 original: $clip" >&2
        fi
      ''}
    '';
  };
  runsPostSave = cfg.postSaveScript != null || cfg.hdrClips != "hdr";

  startScript = pkgs.writeShellApplication {
    name = "start-gsr-replay";
    runtimeInputs = with pkgs; [gpu-screen-recorder findMonitorScript coreutils];
    text = ''
      mkdir -p "${cfg.outputDirectory}"

      ${resolveDisplay}

      exec gpu-screen-recorder \
        -w "$DISPLAY_NAME" \
        -f ${toString cfg.fps} \
        ${audioArgs} \
        -c ${cfg.container} \
        -fm vfr \
        -k ${cfg.codec} \
        -q ${cfg.quality} \
        -r ${toString (cfg.replayDuration + cfg.postRecordSeconds)} \
        ${lib.optionalString usePortal "-restore-portal-session yes"} \
        ${lib.optionalString runsPostSave "-sc ${lib.getExe postSavePipeline}"} \
        -o "${cfg.outputDirectory}"
    '';
  };

  # ExecCondition: skip (not fail) the start while the configured monitor is disconnected.
  monitorPresentScript = pkgs.writeShellApplication {
    name = "gsr-monitor-present";
    runtimeInputs = [findMonitorScript];
    text = ''
      [ -n "$(gsr-find-monitor ${lib.escapeShellArg cfg.matchMonitorName})" ]
    '';
  };

  # Starts the recorder when the configured monitor joins Hyprland and stops it
  # when it leaves — before GSR's own paused-capture restart can reach the picker.
  monitorGateScript = pkgs.writeShellApplication {
    name = "gsr-monitor-gate";
    runtimeInputs = with pkgs; [socat jq systemd];
    text = ''
      hypr="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE"
      unit=gpu-screen-recorder-replay.service

      reconcile() {
        local monitors active
        if ! monitors=$(printf 'j/monitors' | socat - UNIX-CONNECT:"$hypr/.socket.sock"); then
          echo "gsr-monitor-gate: could not query Hyprland at $hypr/.socket.sock — leaving $unit as is" >&2
          return 0
        fi
        if ! active=$(jq -r --arg m ${lib.escapeShellArg (lib.toLower cfg.matchMonitorName)} \
          'any(.[]; .description | ascii_downcase | contains($m))' <<<"$monitors"); then
          echo "gsr-monitor-gate: unreadable monitor list from Hyprland — leaving $unit as is" >&2
          return 0
        fi
        if [ "$active" = true ]; then
          systemctl --user --no-block start "$unit"
        else
          echo "gsr-monitor-gate: '${cfg.matchMonitorName}' is not active — stopping $unit"
          systemctl --user --no-block stop "$unit"
        fi
      }

      reconcile
      socat -U - UNIX-CONNECT:"$hypr/.socket2.sock" | while IFS= read -r event; do
        case $event in
          monitoradded'>>'* | monitorremoved'>>'*) reconcile ;;
        esac
      done
    '';
  };

  # Restarts the recorder when its portal video stream has no pipewire link:
  # GSR stays up encoding the last frame after a stream error.
  healthScript = pkgs.writeShellApplication {
    name = "gsr-health";
    runtimeInputs = with pkgs; [videoStreamScript systemd coreutils];
    text = ''
      unit=gpu-screen-recorder-replay.service

      dead() {
        local state
        state=$(gsr-video-stream "$1") || {
          echo "gsr-health: could not read GSR $1 stream state — skipping this check" >&2
          return 1
        }
        [ "$state" != linked ]
      }

      pid=$(systemctl --user show -p MainPID --value "$unit")
      [ "$pid" -gt 0 ] || exit 0
      dead "$pid" || exit 0

      # Second strike: GSR's own paused-capture restart briefly drops the link.
      sleep 10
      [ "$(systemctl --user show -p MainPID --value "$unit")" = "$pid" ] || exit 0
      dead "$pid" || exit 0

      echo "gsr-health: GSR $pid video stream has no pipewire link — restarting $unit"
      systemctl --user restart "$unit"
    '';
  };
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
        the active monitor, `portal` to capture via xdg-desktop-portal (converts
        HDR to SDR), or a specific connector like `DP-3`.
        When set to `portal`, also setting matchMonitorName installs the smart
        xdph picker that auto-selects that monitor without showing a dialog.
      '';
    };

    matchMonitorName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "LG ULTRAGEAR";
      description = ''
        Dynamically find the monitor by its EDID model name. Case-insensitive
        partial match. More stable than static display names since it works
        regardless of which port the monitor is connected to.

        With `display = null`, this is resolved to a connector at startup and
        passed to gpu-screen-recorder directly.

        With `display = "portal"`, the module installs a custom xdph picker
        (`~/.config/hypr/xdph.conf`) that auto-selects this monitor whenever
        GSR opens a fresh portal session, skipping the share-picker dialog.
        Other screencast clients (browser, Slack, OBS) fall through to the
        normal interactive picker.
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

    container = lib.mkOption {
      type = lib.types.enum ["mp4" "mkv" "flv" "webm"];
      default = "mkv";
      description = ''
        Output container format. MKV is the safest default (survives crashes
        with a still-playable file), but DaVinci Resolve refuses MKV — use
        "mp4" if you import recordings into Resolve.
      '';
    };

    replayDuration = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = ''
        Seconds of pre-trigger footage in the saved clip. The actual GSR
        rolling buffer is sized at `replayDuration + postRecordSeconds` so
        you get the full pre-trigger window even when a tail delay is set.
      '';
    };

    postRecordSeconds = lib.mkOption {
      type = lib.types.int;
      default = 0;
      example = 10;
      description = ''
        Seconds of footage to capture *after* `save-gsr-replay` is invoked.
        The module bumps the GSR rolling buffer to `replayDuration +
        postRecordSeconds` and delays the SIGUSR1 flush by this many
        seconds, so the saved clip is `replayDuration` pre + this many
        post — useful for capturing the reaction to whatever prompted the
        save. Default `0` is no tail (immediate flush). Can be overridden
        per-invocation: `save-gsr-replay 10`.
      '';
    };

    # -- Output --

    outputDirectory = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/Videos/Clips";
      description = "Directory where saved replay clips are stored.";
    };

    postSaveScript = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      example = lib.literalExpression ''pkgs.writeShellApplication { name = "my-hook"; text = "..."; }'';
      description = ''
        Executable run after every save, from gpu-screen-recorder's `-sc` hook,
        which GSR invokes asynchronously. Arguments: the saved filepath and the
        save type (`regular`, `replay`, or `screenshot`). It may move the clip;
        if it does, it prints the new path as its last stdout line (log to
        stderr). `hdrClips` handling then runs on that path.
      '';
    };

    hdrClips = lib.mkOption {
      type = lib.types.enum ["sdr" "both" "hdr"];
      default = "sdr";
      description = ''
        What to keep of a clip recorded as HDR10 (an HDR `codec`). `sdr`
        converts it to SDR (BT.709, NVENC H.264) and drops the original, since
        most players and sites show HDR10 washed out; `both` keeps the original
        too, as `<name>.hdr.<ext>`; `hdr` keeps it as recorded. SDR clips are
        left alone.
      '';
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
      (lib.hm.assertions.assertPlatform "services.gpu-screen-recorder" pkgs lib.platforms.linux)
      {
        assertion = cfg.display != null || cfg.matchMonitorName != null;
        message = "gpu-screen-recorder: Set 'display' (e.g. \"DP-3\" or \"portal\") or 'matchMonitorName'";
      }
    ];

    systemd.user.services.gpu-screen-recorder-replay = {
      Unit = {
        Description = "GPU Screen Recorder Replay Buffer";
        # graphical-session.target reaching doesn't mean the portal/pipewire
        # stack is responsive yet — at boot, GSR races them and the first
        # SelectSources call can fail with "no more input formats". Wait for
        # the actual portal services and verify the dbus interface responds
        # before starting GSR.
        After = [
          "graphical-session.target"
          "pipewire.service"
          "xdg-desktop-portal.service"
          "xdg-desktop-portal-hyprland.service"
        ];
      };

      Service = {
        Type = "simple";
        ExecCondition = lib.mkIf (cfg.matchMonitorName != null) (lib.getExe monitorPresentScript);
        ExecStartPre = lib.getExe waitForPortalScript;
        ExecStart = lib.getExe startScript;
        Restart = "always";
        RestartSec = "5s";
        # GSR ignores SIGTERM while blocked on a portal response (dbus.c has no timeout).
        TimeoutStopSec = "5s";
      };

      Install.WantedBy = ["graphical-session.target"];
    };

    # Hyprland-only: other compositors get no live monitor gating, just ExecCondition at start.
    systemd.user.services.gsr-monitor-gate = lib.mkIf (cfg.matchMonitorName != null) {
      Unit = {
        Description = "Start/stop GPU Screen Recorder with its monitor";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
        ConditionEnvironment = "HYPRLAND_INSTANCE_SIGNATURE";
      };
      Service = {
        ExecStart = lib.getExe monitorGateScript;
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = ["graphical-session.target"];
    };

    # Portal capture only: a direct (KMS) capture has no pipewire video stream to check.
    systemd.user.services.gsr-health = lib.mkIf usePortal {
      Unit.Description = "Restart GPU Screen Recorder if its video stream is dead";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe healthScript;
      };
    };

    systemd.user.timers.gsr-health = lib.mkIf usePortal {
      Unit.Description = "Check the GPU Screen Recorder video stream";
      Timer = {
        OnActiveSec = "30s";
        OnUnitActiveSec = "30s";
      };
      Install.WantedBy = ["timers.target"];
    };

    # Point xdph at the smart picker so GSR's fresh portal sessions get
    # auto-selected to the configured monitor without showing a dialog.
    # Other screencast clients still see the normal share-picker.
    xdg.configFile."hypr/xdph.conf" = lib.mkIf enableAutoPicker {
      text = ''
        screencopy {
          custom_picker_binary = ${lib.getExe smartPickerScript}
          allow_token_by_default = true
        }
      '';
    };

    home.packages =
      [saveReplayScript]
      # Only useful in portal mode WITHOUT matchMonitorName — i.e. when the
      # user picks interactively and may want to force the dialog back.
      # When matchMonitorName is set, the smart picker auto-resolves the
      # configured monitor and the script has nothing meaningful to do.
      ++ lib.optional (usePortal && !enableAutoPicker) repickMonitorScript;

    # Invalidate the cached portal token when matchMonitorName changes.
    # Without this, GSR would keep restoring the previous
    # monitor's portal session even after a rebuild. A sentinel file
    # records the last-applied value so we only act on actual changes.
    home.activation = lib.mkIf enableAutoPicker {
      gsrInvalidateToken = lib.hm.dag.entryAfter ["writeBoundary"] ''
        sentinel="$HOME/.config/gpu-screen-recorder/.configured-monitor"
        configured=${lib.escapeShellArg cfg.matchMonitorName}
        if [ "$(cat "$sentinel" 2>/dev/null || true)" != "$configured" ]; then
          run rm -f "$HOME/.config/gpu-screen-recorder/restore_token"
          run mkdir -p "$(dirname "$sentinel")"
          run sh -c "printf '%s' ${lib.escapeShellArg cfg.matchMonitorName} > $sentinel"
          run ${pkgs.systemd}/bin/systemctl --user try-restart \
            gpu-screen-recorder-replay.service 2>/dev/null || true
        fi
      '';
    };
  };
}
