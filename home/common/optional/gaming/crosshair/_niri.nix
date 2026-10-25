# niri's options exist only on hosts whose NixOS config enables it, hence the `options` check.
{
  config,
  lib,
  options,
  pkgs,
  customPkgs,
  ...
}: let
  toggle = import ./_toggle.nix {
    inherit lib pkgs customPkgs;
    focusedOutput = "${lib.getExe config.programs.niri.package} msg -j focused-output | ${lib.getExe pkgs.jq} -r '.name // empty'";
  };
in {
  config = lib.optionalAttrs (options.programs ? niri) {
    programs.niri.settings.binds."Mod+Shift+C".action.spawn = lib.getExe toggle;
  };
}
