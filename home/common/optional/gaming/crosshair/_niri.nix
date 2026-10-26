{
  config,
  lib,
  pkgs,
  customPkgs,
  ...
}: let
  toggle = import ./_toggle.nix {
    inherit lib pkgs customPkgs;
    focusedOutput = "${lib.getExe config.programs.niri.package} msg -j focused-output | ${lib.getExe pkgs.jq} -r '.name // empty'";
  };
in {
  programs.niri.settings.binds."Mod+Shift+C".action.spawn = lib.getExe toggle;
}
