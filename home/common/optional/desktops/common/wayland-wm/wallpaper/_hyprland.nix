{
  config,
  lib,
  ...
}: {
  wayland.windowManager.hyprland = {
    # SUPER+W → visual picker (Quickshell). One thumbnail click sets that
    # wallpaper on the targeted monitor via wpaperctl and exits.
    # Deliberately *not* SUPER+SHIFT+W: that sits next to SUPER+SHIFT+E
    # (exit hyprland), and a finger-slip there is unrecoverable.
    settings.bind = ["SUPER,w,exec,${lib.getExe config.wallpapers.picker}"];

    # Hyprland #9408: its texture expansion draws wpaperd wrong on rotated outputs.
    settings.render.expand_undersized_textures = false;

    # Float + center the picker on the focused monitor.
    settings.windowrule = [
      "float on, match:title ^(Wallpaper picker)$"
      "size 1600 900, match:title ^(Wallpaper picker)$"
      "center 1, match:title ^(Wallpaper picker)$"
    ];
  };
}
