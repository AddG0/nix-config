# This module just provides a customized .desktop file with gamescope args dynamically created based on the
# host's monitors configuration
{
  pkgs,
  config,
  lib,
  nix-gaming,
  ...
}: let
  monitor = lib.head (lib.filter (m: m.primary) config.monitors);

  steam-session = let
    gamescope = lib.concatStringsSep " " [
      (lib.getExe pkgs.gamescope)
      "--output-width ${toString monitor.width}"
      "--output-height ${toString monitor.height}"
      "--framerate-limit ${toString monitor.refreshRate}"
      "--prefer-output ${monitor.name}"
      "--adaptive-sync"
      "--expose-wayland"
      "--steam"
      "--hdr-enabled"
    ];
    steam = lib.concatStringsSep " " [
      "steam"
      #"steam://open/bigpicture"
    ];
  in
    pkgs.writeTextDir "share/applications/steam-session.desktop" ''
      [Desktop Entry]
      Name=Steam Session
      Exec=${gamescope} -- ${steam}
      Icon=steam
      Type=Application
    '';
in {
  home.packages = [
    steam-session
    # If it says "Corrective action is required to continue" Open Epic Games in the browser
    # https://www.reddit.com/r/SteamDeck/comments/1hu9242/heroic_launcher_login_error/
    pkgs.heroic
  ];
}
