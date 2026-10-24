# niri's options exist only on hosts whose NixOS config enables it, hence the `options` check.
{
  config,
  lib,
  options,
  ...
}: let
  noctalia = lib.getExe config.programs.noctalia.package;
in {
  config = lib.optionalAttrs (options.programs ? niri) {
    programs.niri.settings.binds = {
      "Mod+Space".action.spawn = "walker";
      "Mod+C".action.spawn = [noctalia "msg" "panel-toggle" "control-center" "calendar"];
      "Mod+N".action.spawn = [noctalia "msg" "panel-toggle" "control-center" "notifications"];
    };
  };
}
