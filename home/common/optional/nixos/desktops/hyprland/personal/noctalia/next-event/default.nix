{
  pkgs,
  lib,
  ...
}: let
  # noctalia path baked in for the onClick shell-out (runAsync inherits no PATH).
  entry = pkgs.replaceVars ./next-event.luau {noctalia = lib.getExe pkgs.noctalia;};
in {
  # Install where Noctalia auto-discovers it as a read-only local source. Enabling
  # it and placing it on the bar are view decisions, made in ../default.nix.
  xdg.dataFile = {
    "noctalia/plugins/next-event/plugin.toml".source = ./plugin.toml;
    "noctalia/plugins/next-event/next-event.luau".source = entry;
  };
}
