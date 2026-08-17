{lib, ...}: {
  imports = lib.flatten [
    (map lib.custom.relativeToHome (map (f: "common/optional/${f}") [
      # Gaming
      "gaming"
      "gaming/minecraft"
    ]))
  ];

  #
  # ========== Host-specific Monitor Spec ==========
  #
  # MSI MPG 491C OLED, native mode. Only reaches the per-game gamescope wrapper —
  # the session picks the EDID's preferred timing (3840x1080@60) unless told otherwise.
  display.monitors = [
    {
      output = "HDMI-A-1";
      name = "ultrawide";
      width = 5120;
      height = 1440;
      refreshRate = 144;
      primary = true;
    }
  ];
}
