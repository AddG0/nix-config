# Keeps new popups, such as a 1Password prompt, behind a fullscreen window instead of over it.
{
  config,
  lib,
  pkgs,
  ...
}: let
  listener = pkgs.callPackage ./listener.nix {hyprland = config.wayland.windowManager.hyprland.package;};
in {
  systemd.user.services.hyprland-popups-under-fullscreen = lib.mkMerge [
    config.lib.hyprland.startWithHyprland
    {
      Unit = {
        Description = "Keep new floating windows behind a fullscreen window";
        # HYPRLAND_INSTANCE_SIGNATURE reaches the user manager only once the session is up.
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = lib.getExe listener;
        Restart = "on-failure";
        RestartSec = 5;
      };
    }
  ];
}
