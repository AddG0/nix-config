# Installs `hypr-monitor-control` with the declared layout its `recover` restores.
{
  lib,
  config,
  customPkgs,
  ...
}: let
  # Parse "1, monitor:DP-3, default:true" → { ws = "1"; mon = "DP-3"; }
  wsRules = let
    rules = config.wayland.windowManager.hyprland.settings.workspace or [];
    parseRule = rule: let
      parts = lib.splitString "," rule;
      wsId = lib.trim (builtins.head parts);
      monPart = lib.findFirst (p: lib.hasPrefix "monitor:" (lib.trim p)) null (builtins.tail parts);
      mon =
        if monPart != null
        then lib.removePrefix "monitor:" (lib.trim monPart)
        else null;
    in
      if mon != null
      then {
        ws = wsId;
        inherit mon;
      }
      else null;
  in
    builtins.filter (x: x != null) (map parseRule rules);

  primaryNames = map (m: m.output) (builtins.filter (m: m.primary) config.display.monitors);

  monitor = customPkgs.hypr-monitor-control.override {
    layout =
      if config.display.monitors == []
      then null
      else {
        primaryMonitor = lib.findFirst (_: true) "" primaryNames;
        workspaceMonitors =
          map (r: {
            workspace = r.ws;
            monitor = r.mon;
          })
          wsRules;
      };
  };
in {
  home.packages = [monitor];

  # Safety keybind: re-apply the declared monitor layout if runtime state
  # is wedged (crashed sunshine session, hot-plug glitch, etc).
  # Owns SUPERSHIFT+S — sunshine.nix's bind for the same key was removed
  # so the two don't clobber each other. `sunshine-disconnect` is still
  # invoked by Sunshine's own service hook on normal disconnects, and
  # remains runnable from a shell for headless/noctalia cleanup.
  wayland.windowManager.hyprland.settings.bind = [
    "SUPERSHIFT,r,exec,${lib.getExe monitor} recover"
  ];
}
