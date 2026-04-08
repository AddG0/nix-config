{
  pkgs,
  lib,
  config,
  ...
}: let
  # Laptop-only lid handling for internal displays:
  # - lid close disables eDP outputs
  # - lid open re-enables eDP outputs
  # - when lid is physically closed, open/toggle are forced to close
  isLaptop = config.hostSpec.hostType == "laptop";
  internalMonitorNames = map (m: m.name) (lib.filter (m: lib.hasPrefix "eDP-" m.name) config.monitors);
  internalMonitorsList = lib.concatStringsSep "\n" internalMonitorNames;
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  jq = "${pkgs.jq}/bin/jq";
  # Single helper used by keybinds, lid switch events, resume hooks, and timer guard.
  hyprLaptopLid = pkgs.writeShellScriptBin "hypr-laptop-lid" ''
        set -eu

        action="''${1:-}"
        case "$action" in
          close|open|toggle|sync|resume) ;;
          *)
            echo "hypr-laptop-lid failed: expected action close|open|toggle|sync|resume" >&2
            exit 2
            ;;
        esac

        internal_monitors='${internalMonitorsList}'
        monitors_json="$(${hyprctl} -j monitors all)"

        lid_closed="false"
        for state_file in /proc/acpi/button/lid/*/state; do
          [ -f "$state_file" ] || continue
          state_line=""
          IFS= read -r state_line < "$state_file" || true
          case "$state_line" in
            *closed*)
              lid_closed="true"
              break
              ;;
          esac
        done

        case "$action" in
          resume)
            ${hyprctl} dispatch dpms on
            if [ "$lid_closed" = "true" ]; then
              action="close"
            else
              exit 0
            fi
            ;;
          sync)
            if [ "$lid_closed" = "true" ]; then
              action="close"
            else
              exit 0
            fi
            ;;
          *)
            if [ "$lid_closed" = "true" ] && [ "$action" != "close" ]; then
              action="close"
            fi
            ;;
        esac

        if [ "$action" = "toggle" ]; then
          first_monitor=""
          while IFS= read -r mon; do
            [ -n "$mon" ] || continue
            first_monitor="$mon"
            break
          done <<EOF
    $internal_monitors
    EOF

          if [ -z "$first_monitor" ]; then
            exit 0
          fi

          is_disabled="$(printf '%s' "$monitors_json" | ${jq} -r --arg mon "$first_monitor" '.[] | select(.name == $mon) | .disabled')"

          if [ "$is_disabled" = "true" ]; then
            action="open"
          else
            action="close"
          fi
        fi

        while IFS= read -r mon; do
          [ -n "$mon" ] || continue

          is_disabled="$(printf '%s' "$monitors_json" | ${jq} -r --arg mon "$mon" '.[] | select(.name == $mon) | .disabled')"

          # Skip no-op monitor updates to avoid unnecessary refresh/flicker.
          if [ "$action" = "close" ] && [ "$is_disabled" = "true" ]; then
            continue
          fi

          if [ "$action" = "open" ] && [ "$is_disabled" = "false" ]; then
            continue
          fi

          if [ "$action" = "close" ]; then
            ${hyprctl} keyword monitor "$mon,disable"
          else
            ${hyprctl} keyword monitor "$mon,preferred,auto,1"
          fi
        done <<EOF
    $internal_monitors
    EOF
  '';
in {
  config = lib.mkIf (isLaptop && internalMonitorNames != []) {
    # Lid policy must win over generic OLED/idle defaults to avoid waking eDP on resume.
    services.hypridle.settings.general.after_sleep_cmd = lib.mkForce "${hyprLaptopLid}/bin/hypr-laptop-lid resume";
    # Force listener set so resume always goes through lid-aware sync logic.
    services.hypridle.settings.listener = lib.mkForce [
      {
        timeout = 180;
        on-timeout = "loginctl lock-session";
      }
      {
        timeout = 240;
        on-timeout = "hyprctl dispatch dpms off";
        on-resume = "${hyprLaptopLid}/bin/hypr-laptop-lid resume";
      }
    ];

    # Reconcile state whenever Hyprland config is applied/reloaded.
    wayland.windowManager.hyprland.settings.exec = lib.mkAfter [
      "${hyprLaptopLid}/bin/hypr-laptop-lid sync"
    ];

    # Manual emergency toggle for the internal panel.
    wayland.windowManager.hyprland.settings.bind = lib.mkAfter [
      "SUPERCTRL,o,exec,${hyprLaptopLid}/bin/hypr-laptop-lid toggle"
    ];

    # Hardware lid switch mapping: close lid -> disable internal panel, open lid -> restore.
    wayland.windowManager.hyprland.settings.bindl = lib.mkAfter [
      ",switch:on:Lid Switch,exec,${hyprLaptopLid}/bin/hypr-laptop-lid close"
      ",switch:off:Lid Switch,exec,${hyprLaptopLid}/bin/hypr-laptop-lid open"
    ];

    # Periodic guard for edge cases (resume races, missed switch events, config reapply).
    systemd.user.services.hypr-laptop-lid-guard = {
      Unit = {
        Description = "Keep laptop panel off while lid is closed";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -lc '${hyprctl} -j monitors all >/dev/null 2>&1 && ${hyprLaptopLid}/bin/hypr-laptop-lid sync || true'";
      };
    };

    # Low-frequency timer keeps overhead tiny while still correcting drift quickly.
    systemd.user.timers.hypr-laptop-lid-guard = {
      Unit.Description = "Periodic laptop lid display guard";
      Timer = {
        OnBootSec = "30s";
        OnUnitActiveSec = "20s";
        AccuracySec = "5s";
        Unit = "hypr-laptop-lid-guard.service";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
