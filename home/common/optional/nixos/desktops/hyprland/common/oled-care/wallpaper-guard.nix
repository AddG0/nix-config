{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.oledCare.wallpaperGuard;
  oledMonitors = lib.filter (m: m.oled && m.enabled) config.display.monitors;

  # Smallest possible solid-black PNG. hyprpaper scales it to fill the
  # monitor, so 1x1 is sufficient — and pure black pixels on OLED don't
  # emit, regardless of "image" size.
  blackPng = pkgs.runCommand "oled-black.png" {nativeBuildInputs = [pkgs.imagemagick];} ''
    magick -size 1x1 xc:black "$out"
  '';

  blackPath = toString blackPng;

  # hyprpaper's home-manager module accepts either "monitor,path" strings
  # or { monitor; path; } attrsets — stylix uses the attrset form, so match
  # it. Force outPath via toString so the value type stays a plain string
  # (raw derivations through the recursive option type can blow the stack).
  wallpaperEntries =
    map (m: {
      monitor = m.name;
      path = blackPath;
    })
    oledMonitors;
in {
  config = lib.mkIf (cfg.enable && oledMonitors != []) {
    services.hyprpaper = {
      enable = true;
      # mkAfter so any wildcard rule from stylix is overridden by these
      # monitor-specific entries (hyprpaper applies later matches last).
      settings = {
        preload = lib.mkAfter [blackPath];
        wallpaper = lib.mkAfter wallpaperEntries;
      };
    };

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
