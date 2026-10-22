{lib}: rec {
  transformMap = {
    "normal" = 0;
    "90" = 1;
    "180" = 2;
    "270" = 3;
    "flipped" = 4;
    "flipped-90" = 5;
    "flipped-180" = 6;
    "flipped-270" = 7;
  };

  vrrMap = {
    "off" = 0;
    "on" = 1;
    "fullscreen-only" = 2;
    "fullscreen-game" = 3;
  };

  # One display.monitors entry as a Hyprland monitorv2 block; unset options are left to Hyprland's defaults.
  monitorv2 = m:
    if m.enabled
    then
      {
        inherit (m) output;
        mode = "${toString m.width}x${toString m.height}@${toString m.refreshRate}.0";
        position = "${toString m.x}x${toString m.y}";
        scale = toString m.scale;
        transform = transformMap.${m.transform};
        vrr = vrrMap.${m.vrr};
      }
      // lib.optionalAttrs (m.bitdepth != 8) {inherit (m) bitdepth;}
      // lib.optionalAttrs m.hdr {cm = "hdr";}
      // lib.filterAttrs (_: v: v != null) {
        sdr_max_luminance = m.sdrMaxLuminance;
        sdr_min_luminance = m.sdrMinLuminance;
        sdrbrightness = m.sdrBrightness;
        sdrsaturation = m.sdrSaturation;
        sdr_eotf = m.sdrEotf;
        supports_wide_color = lib.mapNullable (b:
          if b
          then 1
          else 0)
        m.supportsWideColor;
        supports_hdr = lib.mapNullable (b:
          if b
          then 1
          else 0)
        m.supportsHdr;
        min_luminance = m.minLuminance;
        max_luminance = m.maxLuminance;
        max_avg_luminance = m.maxAvgLuminance;
        inherit (m) icc mirror;
        addreserved =
          lib.mapNullable (r: "${toString r.top}, ${toString r.bottom}, ${toString r.left}, ${toString r.right}") m.reserved;
      }
    else {
      inherit (m) output;
      disabled = true;
    };
}
