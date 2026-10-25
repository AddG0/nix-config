# Super+Shift+T: btop in a floating window, toggled — niri's counterpart of hyprland/_common/btop.nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Own app-id so the window rule below can't catch a regular ghostty window.
  appId = "dev.addg.btop";

  toggle = pkgs.writeShellApplication {
    name = "niri-btop-toggle";
    runtimeInputs = [config.programs.niri.package pkgs.jq];
    text = ''
      id=$(niri msg -j windows | jq -r --arg a ${lib.escapeShellArg appId} 'first(.[] | select(.app_id == $a) | .id) // ""')
      if [ -n "$id" ]; then
        exec niri msg action close-window --id "$id"
      fi
      exec ${lib.getExe pkgs.ghostty} --class=${appId} --title=btop --confirm-close-surface=false \
        -e ${config.programs.btop.package}/bin/btop
    '';
  };
in {
  programs.niri.settings = {
    binds."Mod+Shift+T".action.spawn = lib.getExe toggle;

    window-rules = [
      {
        matches = [{app-id = "^${lib.escapeRegex appId}$";}];
        open-floating = true;
        default-column-width.proportion = 0.65;
        default-window-height.proportion = 0.7;
      }
    ];
  };
}
