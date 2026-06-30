{
  pkgs,
  lib,
  ...
}: let
  # Binary paths baked in for the runAsync shell-outs (runAsync inherits no PATH):
  # noctalia for the onClick panel toggle, jq for filtering the event cache.
  entry = pkgs.replaceVars ./next-event.luau {
    noctalia = lib.getExe pkgs.noctalia;
    jq = lib.getExe pkgs.jq;
  };
in {
  # Install where Noctalia auto-discovers it as a read-only local source. Enabling
  # it and placing it on the bar are view decisions, made in ../default.nix.
  xdg.dataFile = {
    "noctalia/plugins/next-event/plugin.toml".source = ./plugin.toml;
    "noctalia/plugins/next-event/next-event.luau".source = entry;
  };
}
