{
  pkgs,
  lib,
  ...
}: let
  mkPlugin = import ../_mk-plugin.nix {inherit pkgs lib;};
in {
  xdg.dataFile = mkPlugin {
    dir = ./.;
    templates."next-event.luau" = {
      noctalia = lib.getExe pkgs.noctalia;
      jq = lib.getExe pkgs.jq;
    };
  };

  programs.noctalia.settings = {
    plugins.enabled = ["addg/next-event"];
    # Takes over the bar's existing `calendar` slot rather than adding one.
    widget.calendar.type = "addg/next-event:agenda";
  };
}
