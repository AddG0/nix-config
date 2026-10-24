{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.oledCare.wallpaperGuard;
  oledMonitors = lib.filter (m: m.oled && m.enabled) config.display.monitors;

  # Smallest possible solid-black PNG. wpaperd scales it to fill the
  # monitor, so 1x1 is sufficient — and pure black pixels on OLED don't
  # emit, regardless of "image" size.
  blackPng = pkgs.runCommand "oled-black.png" {nativeBuildInputs = [pkgs.imagemagick];} ''
    magick -size 1x1 xc:black "$out"
  '';

  # wpaperd matches the most specific output key — these per-output entries
  # win over the `any` rotation set in wallpaper.nix. No rotation here:
  # the singleton `path = <black.png>` pins each OLED output to black.
  oledSettings = lib.listToAttrs (map (m: {
      name = m.output;
      value.path = toString blackPng;
    })
    oledMonitors);
in {
  config = lib.mkIf (cfg.enable && oledMonitors != []) {
    services.wpaperd.settings = oledSettings;

    # Per-output lock-background override: black for each OLED monitor.
    # Written into hyprlock's `backgroundOverrides` hook so hyprlock can
    # consume it without ever referencing oled-care.
    programs.hyprlock.backgroundOverrides = lib.listToAttrs (map (m: {
        name = m.output;
        value = {color = "rgb(0,0,0)";};
      })
      oledMonitors);
  };
}
