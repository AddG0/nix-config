{pkgs, ...}: let
  softwareDimming = import ./script.nix {inherit pkgs;};
in {
  wayland.windowManager.hyprland = {
    extraConfig = ''
      # Replace broken hardware backlight keys on this OLED panel with a
      # Hyprland shader dimmer. Order matters here: unbind first, then rebind.
      exec = ${softwareDimming}/bin/hypr-software-brightness apply
      unbind = ,XF86MonBrightnessUp
      unbind = ,XF86MonBrightnessDown
      binde = ,XF86MonBrightnessUp,exec,${softwareDimming}/bin/hypr-software-brightness up
      binde = ,XF86MonBrightnessDown,exec,${softwareDimming}/bin/hypr-software-brightness down
      bind = SUPERSHIFT,backslash,exec,${softwareDimming}/bin/hypr-software-brightness reset
    '';
  };
}
