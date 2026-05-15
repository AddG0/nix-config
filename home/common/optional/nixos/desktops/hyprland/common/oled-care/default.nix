{
  lib,
  config,
  ...
}: let
  hasOled = lib.any (m: m.oled) config.display.monitors;
in {
  imports = [
    ./options.nix
    ./idle-dpms.nix
    ./wallpaper-guard.nix
    ./wear-tracker.nix
  ];

  # Each submodule gates itself on the relevant `services.oledCare.*.enable`
  # AND on the presence of OLED monitors. When no OLED monitor is declared,
  # disable the whole feature tree to avoid configuring hypridle / hyprpaper
  # / timers for nothing.
  config = lib.mkIf (!hasOled) {
    services.oledCare = {
      idleDpms.enable = lib.mkDefault false;
      wallpaperGuard.enable = lib.mkDefault false;
      wearTracker.enable = lib.mkDefault false;
    };
  };
}
