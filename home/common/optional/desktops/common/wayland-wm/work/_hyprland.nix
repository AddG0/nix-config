{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.wayland.windowManager.hyprland.enable {
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "waybar"
      "${pkgs.blueman}/bin/blueman-applet"
      "${pkgs.mako}/bin/mako"
    ];
    bind = ["SUPER,space,exec,wofi --show drun"];
    binde = [
      ",XF86AudioRaiseVolume,exec,swayosd-client --output-volume raise"
      ",XF86AudioLowerVolume,exec,swayosd-client --output-volume lower"
      ",XF86MonBrightnessUp,exec,swayosd-client --brightness raise"
      ",XF86MonBrightnessDown,exec,swayosd-client --brightness lower"
    ];
    bindl = [
      ",XF86AudioMute,exec,swayosd-client --output-volume mute-toggle"
      ",XF86AudioMicMute,exec,swayosd-client --input-volume mute-toggle"
    ];
  };
}
