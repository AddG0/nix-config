{
  hostSpec,
  lib,
  pkgs,
  ...
}:
lib.mkIf (hostSpec.hostType == "laptop") {
  home.packages = [pkgs.nwg-displays];

  wayland.windowManager.hyprland = {
    # Sourced last so nwg-displays overrides declarative monitor rules
    extraConfig = ''
      source = ~/.config/hypr/monitors.conf
    '';
  };
}
