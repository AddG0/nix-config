{pkgs, ...}: {
  services.mako = {
    enable = true;
    settings = {
      # No outline — elevation separates the notification from the content.
      border-radius = 16;
      border-size = 0;
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
  };
}
