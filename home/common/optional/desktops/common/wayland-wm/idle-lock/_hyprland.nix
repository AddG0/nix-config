{
  config,
  lib,
  ...
}:
lib.mkIf config.wayland.windowManager.hyprland.enable {
  wayland.windowManager.hyprland.settings.bind = [
    "SUPER,escape,exec,pidof hyprlock || hyprlock"
  ];
}
