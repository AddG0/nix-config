{pkgs, ...}: {
  wayland.windowManager.hyprland.settings = {
    source = [
      "${pkgs.themes.catppuccin.hyprland}/themes/mocha.conf"
    ];

    general.border_size = 4;

    decoration = {
      rounding = 8;
      active_opacity = 1.0;
      inactive_opacity = 0.9;
      fullscreen_opacity = 1.0;
      blur = {
        enabled = true;
        size = 3;
        passes = 1;
        ignore_opacity = false;
      };
    };

    animations = {
      enabled = true;
      animation = [
        "windows,1,3,default,popin 80%"
        "fadeOut,1,3,default"
        "fadeIn,1,3,default"
        "workspaces,1,3,default"
        "layers,1,3,default,fade"
      ];
    };
  };
}
