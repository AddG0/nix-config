# Screencast fixes for casting: a retry path that gave up permanently, and a
# 4-buffer pool too small for high-resolution capture. See each patch header.
#
# An overlay rather than xdg.portal.extraPortals so it replaces the xdph
# programs.hyprland pulls in, instead of adding a second copy.
_: _final: prev:
prev.lib.optionalAttrs (prev ? xdg-desktop-portal-hyprland) {
  xdg-desktop-portal-hyprland = prev.xdg-desktop-portal-hyprland.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        ./xdph-screencopy-retry.patch
        ./xdph-buffer-pool.patch
      ];
  });
}
