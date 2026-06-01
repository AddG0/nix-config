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
#
# AFTER REBUILDS:
#   xdph reads `~/.config/hypr/xdph.conf` only at startup. Since the smart
#   picker's nix store path changes on every rebuild, restart xdph for the
#   new picker to take effect (or reboot):
#     systemctl --user restart xdg-desktop-portal-hyprland.service
#   Changes to matchMonitorName itself are handled automatically by a
#   home-manager activation hook: it clears the cached portal token and
#   restarts the replay service when the configured monitor changes.
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
    runtimeInputs = with pkgs; [findMonitorScript procps coreutils xdg-desktop-portal-hyprland];
    text = ''
      allow_token=""
      for arg in "$@"; do
        [ "$arg" = "--allow-token" ] && allow_token="r"
      done

      # Decide if this picker invocation is for GSR's screencast request:
      # GSR is running AND its process is young (started within 30s). Covers
      # fresh boot, gsr-repick-monitor, and systemd retries after monitor
      # disable/disconnect. Older GSR processes are in steady-state streaming,
      # so any picker invocation then must be for some other client (Slack
      # screen-share, browser, OBS) and gets the real interactive picker.
      #
      # Use `pidof` (matches binary name) rather than `pgrep -x` (matches only
      # the 15-char kernel COMM, which truncates "gpu-screen-recorder").
      gsr_is_requesting=no
      if gsr_pid=$(pidof gpu-screen-recorder 2>/dev/null); then
        gsr_age=$(ps -o etimes= -p "$gsr_pid" 2>/dev/null | tr -d ' ' || echo 0)
        [ "''${gsr_age:-0}" -lt 30 ] && gsr_is_requesting=yes
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
        # dialog — just fail so xdph rejects the session, GSR exits, and
        # systemd retries. When the monitor returns, the retry auto-picks.
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

  # Long-running supervisor:
  #
  #   loop:
  #     1. Wait until the configured monitor is both physically connected
  #        (kernel `/sys/class/drm/.../status`) AND active in the wayland
  #        compositor (wlr-randr). Idle on `udevadm monitor` for DRM events,
  #        with periodic wlr-randr checks to catch compositor-level changes
  #        (e.g. user-disable) that don't fire kernel events.
  #     2. Start GSR via coproc so we have its PID for kill().
  #     3. Watchdog polls wlr-randr every 10s. If the monitor disappears
  #        from compositor outputs (compositor-disable, unplug, etc.), kill
  #        GSR — otherwise screencopy keeps delivering stale buffers from
  #        the old session and GSR doesn't notice.
  #     4. Stream GSR output; kill on the boot-race format-negotiation
  #        failure signature.
  #     5. If GSR exited within 10s, sleep before respawn (avoid hot loop
  #        on a compositor that re-disables the output immediately).
  #
  # Compositor coverage: works on any wlroots-based compositor (Hyprland,
  # Sway, niri, river, …) via wlr-output-management protocol. KDE Plasma
  # and GNOME use different protocols; for those, only the DRM-level checks
  # apply (physical unplug works; compositor-level disable won't be caught).
  #
  # systemd Restart=on-failure stays as a safety net for genuine crashes.
  startScript = pkgs.writeShellApplication {
    name = "start-gsr-replay";
    runtimeInputs = with pkgs; [gpu-screen-recorder findMonitorScript systemd coreutils wlr-randr gawk];
    text = ''
      mkdir -p "${cfg.outputDirectory}"

      ${resolveDisplay}

      # If matchMonitorName is set, resolve it to a DRM connector and find
      # its sysfs status file. The supervisor only does presence checks
      # with a known connector — otherwise GSR runs unsupervised.
      status_file=""
      ${lib.optionalString (cfg.matchMonitorName != null) ''
        expected=$(gsr-find-monitor ${lib.escapeShellArg cfg.matchMonitorName} || true)
        if [ -n "$expected" ]; then
          for f in /sys/class/drm/card*-"$expected"/status; do
            [ -f "$f" ] && status_file="$f" && break
          done
        fi
      ''}

      drm_connected() {
        [ -z "$status_file" ] && return 0
        [ "$(cat "$status_file" 2>/dev/null)" = "connected" ]
      }

      compositor_has_output() {
        [ -z "''${expected:-}" ] && return 0
        # wlr-randr lists disabled outputs too (just marked "Enabled: no"),
        # so we need to verify the connector's block contains "Enabled: yes".
        wlr-randr 2>/dev/null | awk -v conn="$expected" '
          $1 == conn { inblock = 1; next }
          inblock && /^[^ ]/ { inblock = 0 }
          inblock && /Enabled: yes/ { found = 1 }
          END { exit !found }
        '
      }

      monitor_ready() {
        drm_connected && compositor_has_output
      }

      # Block until either the next DRM uevent or a 10s tick. The DRM event
      # covers physical (un)plug; the periodic tick covers compositor-level
      # state changes that don't fire kernel events.
      wait_for_monitor_change() {
        timeout 10 udevadm monitor --kernel --subsystem-match=drm 2>/dev/null \
          | head -n 1 >/dev/null || true
      }

      while true; do
        while ! monitor_ready; do
          echo "start-gsr-replay: waiting for '$expected' (drm+wayland) to be ready" >&2
          wait_for_monitor_change
        done

        gsr_started_at=$(date +%s)

        coproc GSR { exec gpu-screen-recorder \
          -w "$DISPLAY_NAME" \
          -f ${toString cfg.fps} \
          ${audioArgs} \
          -c ${cfg.container} \
          -fm vfr \
          -k ${cfg.codec} \
          -q ${cfg.quality} \
          -r ${toString (cfg.replayDuration + cfg.postRecordSeconds)} \
          ${lib.optionalString usePortal "-restore-portal-session yes"} \
          -o "${cfg.outputDirectory}" 2>&1; }

        # Watchdog: kill GSR if the monitor leaves the compositor's output
        # list (xdph keeps delivering stale buffers otherwise — GSR has no
        # way to know).
        (
          while sleep 10; do
            compositor_has_output || {
              echo "gsr: '$expected' no longer in compositor outputs — killing GSR" >&2
              kill "$GSR_PID" 2>/dev/null || true
              exit 0
            }
          done
        ) &
        watchdog_pid=$!

        while IFS= read -r line <&"''${GSR[0]}"; do
          printf '%s\n' "$line"
          case $line in
            *"no more input formats"*)
              echo "gsr: pipewire format negotiation failed — killing GSR" >&2
              kill "$GSR_PID" 2>/dev/null || true
              break
              ;;
          esac
        done
        wait "$GSR_PID" 2>/dev/null || true
        kill "$watchdog_pid" 2>/dev/null || true
        wait "$watchdog_pid" 2>/dev/null || true

        runtime=$(( $(date +%s) - gsr_started_at ))
        if [ "$runtime" -lt 10 ]; then
          echo "start-gsr-replay: GSR exited after $runtime s; backing off 10s" >&2
          sleep 10
        fi
      done
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
        ExecStartPre = lib.getExe waitForPortalScript;
        ExecStart = lib.getExe startScript;
        # The supervisor loop in start-gsr-replay handles monitor disappear
        # and respawns GSR internally. on-failure is a safety net for the
        # unlikely case the supervisor itself dies.
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install.WantedBy = ["graphical-session.target"];
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
    # Without this, the supervisor would keep restoring the previous
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
