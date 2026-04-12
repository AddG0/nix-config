{
  programs.hyprlock.enable = true;

  wayland.windowManager.hyprland.settings.bind = [
    "SUPER,escape,exec,pidof hyprlock || hyprlock"
  ];
}
