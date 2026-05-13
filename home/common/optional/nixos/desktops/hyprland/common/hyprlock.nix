{
  programs.hyprlock = {
    enable = true;
    settings.general.hide_cursor = true;
  };

  wayland.windowManager.hyprland.settings.bind = [
    "SUPER,escape,exec,pidof hyprlock || hyprlock"
  ];
}
