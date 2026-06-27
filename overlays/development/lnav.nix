# lnav 0.14.0 segfaults in external_log_format::json_append: it indexes the
# per-file lffs_value_stats vector by a value_def's index with no bounds check,
# so a JSON/ecs_log line whose index exceeds the file's stats reads out of
# bounds. Triggered by terminal captures mixing ecs_log + logfmt (the prefix+L/M
# lnav popups). Drop once fixed upstream (tstack/lnav).
_: _final: prev: {
  lnav = prev.lnav.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./lnav-json-append-oob.patch];
  });
}
