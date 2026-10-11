{
  lib,
  pkgs,
  ...
}: let
  nightlight = lib.getExe pkgs.nightlight;
  # 0 = coolest, 100 = warmest.
  warmth = "100";
  # Fixed times, not sunset/sunrise: that mode needs Location Services granted by hand.
  from = "21:00";
  to = "07:00";
in {
  assertions = [(lib.hm.assertions.assertPlatform "desktops.macos.night-shift" pkgs lib.platforms.darwin)];

  home.packages = [pkgs.nightlight];

  home.activation.nightShift = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${nightlight} temp ${warmth}
    run ${nightlight} schedule ${from} ${to}
  '';
}
