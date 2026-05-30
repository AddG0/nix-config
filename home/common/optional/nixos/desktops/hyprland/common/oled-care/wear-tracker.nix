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
    runtimeInputs = with pkgs; [hyprland jq coreutils];
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

  # Convenience reader — `oled-wear` prints accumulated hours per monitor.
  readerScript = pkgs.writeShellApplication {
    name = "oled-wear";
    runtimeInputs = with pkgs; [jq coreutils];
    text = ''
      state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/oled-care/wear.json"
      if [ ! -s "$state_file" ]; then
        echo "no wear data yet ($state_file)"
        exit 0
      fi
      jq -r 'to_entries[] | "\(.key)\t\(.value / 3600 | . * 10 | floor / 10) hours"' "$state_file"
    '';
  };
in {
  config = lib.mkIf (cfg.enable && oledMonitors != []) {
    home.packages = [trackerScript readerScript];

    systemd.user.services.oled-wear-tracker = {
      Unit = {
        Description = "OLED active-emission wear tracker";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${trackerScript}/bin/oled-wear-tracker";
      };
    };

    systemd.user.timers.oled-wear-tracker = {
      Unit.Description = "OLED wear tracker timer";
      Timer = {
        OnActiveSec = "${toString pollIntervalSec}s";
        OnUnitActiveSec = "${toString pollIntervalSec}s";
        AccuracySec = "5s";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
