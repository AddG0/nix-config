{pkgs, ...}: {
  services.mako = {
    enable = true;
    settings = {
      border-radius = 12;
      border-size = 1;
      default-timeout = 5000;
      padding = "14,18";
      margin = "12";
      width = 360;
      max-icon-size = 48;
      icon-location = "left";
      layer = "overlay";

      "[urgency=high]" = {
        default-timeout = 8000;
      };
    };
  };

  wayland.windowManager.hyprland.settings = {
    exec-once = ["${pkgs.mako}/bin/mako"];
    layerrule = [
      "blur on, match:namespace makoctl"
      "ignore_alpha 0.3, match:namespace makoctl"
    ];
  };
}
