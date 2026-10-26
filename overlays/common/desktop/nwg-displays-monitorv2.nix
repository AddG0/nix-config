# Hyprland applies monitorv2 blocks after every monitor= line, so nwg-displays'
# saved layout never beats an output declared in display.monitors. The patch
# saves monitorv2 blocks; one for a declared output overrides only nwg's keys.
# Upstream: github.com/nwg-piotr/nwg-displays/issues/91 (0.5.0 still writes monitor=).
_: _final: prev: {
  nwg-displays = prev.nwg-displays.overridePythonAttrs (old: {
    patches = (old.patches or []) ++ [./nwg-displays-monitorv2.patch];
  });
}
