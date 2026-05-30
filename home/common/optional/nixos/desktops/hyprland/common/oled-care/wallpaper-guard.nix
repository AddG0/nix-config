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

    # Force hyprlock to draw a pure-black backdrop so the (typically 60s)
    # window between lock and DPMS-off doesn't render the stylix wallpaper
    # — that wallpaper would otherwise be a static OLED burn risk.
    # mkForce overrides stylix's single-attrset definition; this is global
    # (no per-monitor split) because home-manager's hyprlock module types
    # `background` as a singleton attrset, not a list of monitor blocks.
    programs.hyprlock.settings.background = lib.mkForce {
      color = "rgb(0,0,0)";
    };
  };
}
