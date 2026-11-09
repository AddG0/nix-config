# Desktop behaviour layered onto the base noctalia from input-packages: clicking
# a notification toast focuses the originating app via the wlr foreign-toplevel
# protocol (the path noctalia's dock uses), instead of only firing the app's
# DBus `default` action — which relies on the app raising itself via
# xdg-activation (and is gated by Hyprland's focus_on_activate).
_: _final: prev:
prev.lib.optionalAttrs (prev ? noctalia) {
  noctalia = prev.noctalia.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./noctalia-notification-focus-app.patch];
  });
}
