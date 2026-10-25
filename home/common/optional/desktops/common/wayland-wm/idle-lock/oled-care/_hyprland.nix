# Wear tracking under Hyprland: polls `hyprctl monitors` for each OLED panel's DPMS state.
{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.oledCare.wearTracker;
  oledMonitors = lib.filter (m: m.oled) config.display.monitors;
  oledNames = map (m: m.output) oledMonitors;

  pollIntervalSec = 60;

  trackerScript = pkgs.writeShellApplication {
    name = "oled-wear-tracker";
    runtimeInputs = [config.wayland.windowManager.hyprland.package pkgs.jq pkgs.coreutils];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/oled-care"
      state_file="$state_dir/wear.json"
      mkdir -p "$state_dir"

      [ -s "$state_file" ] || printf '{}\n' > "$state_file"

      # Snapshot DPMS status for each OLED monitor. `dpmsStatus: true` means
      # the panel is actively emitting (pixels aging); false means firmware-off.
      monitors_json="$(hyprctl monitors -j 2>/dev/null)" || exit 0

      # shellcheck disable=SC2043  # loop expands to N monitor names at build time
      for name in ${lib.concatStringsSep " " (map lib.escapeShellArg oledNames)}; do
        active="$(printf '%s' "$monitors_json" \
          | jq --arg n "$name" '[.[] | select(.name == $n) | .dpmsStatus] | first // false')"
        if [ "$active" = "true" ]; then
          jq --arg n "$name" --argjson add ${toString pollIntervalSec} \
            '.[$n] = ((.[$n] // 0) + $add)' \
            "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
        fi
      done
    '';
  };
in {
  config = lib.mkIf (cfg.enable && oledMonitors != [] && config.wayland.windowManager.hyprland.enable) {
    home.packages = [trackerScript];

    systemd.user.services.oled-wear-tracker = {
      Unit = {
        Description = "OLED active-emission wear tracker";
        After = ["graphical-session.target"];
        PartOf = [config.lib.hyprland.sessionUnit];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${trackerScript}/bin/oled-wear-tracker";
      };
    };

    systemd.user.timers.oled-wear-tracker = {
      Unit = {
        Description = "OLED wear tracker timer";
        PartOf = [config.lib.hyprland.sessionUnit];
      };
      Timer = {
        OnActiveSec = "${toString pollIntervalSec}s";
        OnUnitActiveSec = "${toString pollIntervalSec}s";
        AccuracySec = "5s";
      };
      Install.WantedBy = [config.lib.hyprland.sessionUnit];
    };
  };
}
