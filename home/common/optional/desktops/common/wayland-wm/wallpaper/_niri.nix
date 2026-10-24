# niri's options exist only on hosts whose NixOS config enables it, hence the `options` check.
{
  config,
  lib,
  options,
  ...
}: {
  config = lib.optionalAttrs (options.programs ? niri) {
    programs.niri.settings = {
      binds."Mod+W".action.spawn = lib.getExe config.wallpapers.picker;
      window-rules = [
        {
          matches = [{title = "^Wallpaper picker$";}];
          open-floating = true;
          default-column-width.fixed = 1600;
          default-window-height.fixed = 900;
        }
      ];
    };
  };
}
