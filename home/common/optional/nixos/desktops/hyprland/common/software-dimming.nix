{pkgs, ...}: let
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
in {
  # Drives brightness via hyprsunset's CTM path, which (unlike a screen shader)
  # is not captured by wlr-screencopy — so screenshots aren't dimmed.
  services.hyprsunset.enable = true;

  wayland.windowManager.hyprland.extraConfig = ''
    unbind = ,XF86MonBrightnessUp
    unbind = ,XF86MonBrightnessDown
    binde = ,XF86MonBrightnessUp,exec,${hyprctl} hyprsunset gamma +5
    binde = ,XF86MonBrightnessDown,exec,${hyprctl} hyprsunset gamma -5
    bind = SUPERSHIFT,backslash,exec,${hyprctl} hyprsunset gamma 100
  '';
}
