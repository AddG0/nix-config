# librepods unlinks /tmp/app_server immediately before probing it, so its
# single-instance check never fires and every launch starts another copy.
# Upstream linux/main.cpp:1012, still present on main as of v1.0.0-rc1.
_: _final: prev:
prev.lib.optionalAttrs (prev ? librepods) {
  librepods = prev.librepods.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./librepods-single-instance.patch];
  });
}
