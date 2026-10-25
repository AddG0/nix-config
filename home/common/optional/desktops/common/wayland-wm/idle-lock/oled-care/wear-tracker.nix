# `oled-wear`: accumulated active-emission hours per OLED monitor, from the tracker's state file.
{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.oledCare.wearTracker;
  oledMonitors = lib.filter (m: m.oled) config.display.monitors;

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
  # The tracker itself reads DPMS state per compositor; see _hyprland.nix.
  config = lib.mkIf (cfg.enable && oledMonitors != []) {
    home.packages = [readerScript];
  };
}
