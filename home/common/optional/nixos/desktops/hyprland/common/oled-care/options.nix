{lib, ...}: {
  options.services.oledCare = {
    idleDpms.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Lock then DPMS-off OLED monitors after idle (hypridle).";
    };

    wallpaperGuard.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Force OLED monitors' wallpaper to pure black via wpaperd.
        Overrides stylix's image on OLED outputs only.
      '';
    };

    wearTracker.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Track cumulative DPMS-on (active emission) hours per OLED monitor
        in $XDG_STATE_HOME/oled-care/wear.json.
      '';
    };
  };
}
