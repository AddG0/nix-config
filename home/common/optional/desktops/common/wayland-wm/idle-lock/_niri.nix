# niri's options exist only on hosts whose NixOS config enables it, hence the `options` check.
{
  lib,
  options,
  ...
}: {
  config = lib.optionalAttrs (options.programs ? niri) {
    programs.niri.settings.binds."Mod+Escape".action.spawn-sh = "pidof hyprlock || hyprlock";
  };
}
