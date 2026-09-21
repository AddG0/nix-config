# gamescope's vendored wlroots rejects its own Xwayland socket dir as
# "not owned by root or us" inside Steam's FHS sandbox, killing gamescope
# (SIGSEGV on the resulting NULL Xwayland handle) before any game starts.
# Confirmed against Portal 2 (appid 620): journalctl shows
# `[xwayland/sockets.c:83] /tmp/.X11-unix not owned by root or us` x32 then
# `No display available`. Root cause: gamescope/wlroots's ownership check
# isn't userns-aware (open upstream: gitlab.freedesktop.org/wlroots/wlroots/-/issues/3805).
# Fixed once gamescope's wlroots submodule carries that upstream fix.
# CHECK-RUNTIME: launch a Steam game with gamescope enabled; upstream is fixed
# when `journalctl --user -b | grep -i "not owned by root or us"` is empty
# after removing this overlay.
_: _final: prev: {
  gamescope = prev.gamescope.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./gamescope-x11-unix-ownership.patch];
  });
}
