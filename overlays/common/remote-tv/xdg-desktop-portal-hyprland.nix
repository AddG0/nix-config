# Screencast fix for casting: a 4-buffer pool too small for high-resolution
# capture. See the patch header.
#
# An overlay rather than xdg.portal.extraPortals so it replaces the xdph
# programs.hyprland pulls in, instead of adding a second copy.
_: _final: prev:
prev.lib.optionalAttrs (prev ? xdg-desktop-portal-hyprland) {
  xdg-desktop-portal-hyprland = prev.xdg-desktop-portal-hyprland.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./xdph-buffer-pool.patch];
  });
}
