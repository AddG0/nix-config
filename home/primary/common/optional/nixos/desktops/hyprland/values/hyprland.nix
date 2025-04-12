{
  pkgs,
  lib,
  nur-ryan4yin,
  config,
  ...
}: let
  package = pkgs.hyprland;
in {
  # NOTE:
  # We have to enable hyprland/i3's systemd user service in home-manager,
  # so that gammastep/wallpaper-switcher's user service can be start correctly!
  # they are all depending on hyprland/i3's user graphical-session
  wayland.windowManager.hyprland = {
    inherit package;
    enable = true;
    settings = {
      source = lib.flatten [
        "${nur-ryan4yin.packages.${pkgs.system}.catppuccin-hyprland}/themes/mocha.conf"
        (lib.optionals (builtins.head config.monitors).use_nwg [
          "~/.config/hypr/monitors.conf"
          "~/.config/hypr/workspaces.conf"
        ])
      ];
      env = [
        "NIXOS_OZONE_WL,1" # for any ozone-based browser & electron apps to run on wayland
        "MOZ_ENABLE_WAYLAND,1" # for firefox to run on wayland
        "MOZ_WEBRENDER,1"
        # misc
        "_JAVA_AWT_WM_NONREPARENTING,1"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "QT_QPA_PLATFORM,wayland"
        "SDL_VIDEODRIVER,wayland"
        "GDK_BACKEND,wayland"
        "OGL_DEDICATED_HW_STATE_PER_CONTEXT,ENABLE_ROBUST"
        # fix https://github.com/hyprwm/Hyprland/issues/1520 laggy mouse
        "WLR_NO_HARDWARE_CURSORS,1"
      ];

      cursor = {
        no_hardware_cursors = true;
      };
      #
      # ========== Monitor ==========
      #
      # parse the monitor spec defined in nix-config/home/<user>/<host>.nix
      monitor = lib.mkIf (!(builtins.head config.monitors).use_nwg) (
        map (
          m: "${m.name},${
            if m.enabled
            then "${
              if m.resolution != null
              then m.resolution
              else "${toString m.width}x${toString m.height}@${toString m.refreshRate}"
            },${
              if m.position != null
              then m.position
              else "${toString m.x}x${toString m.y}"
            },1,transform,${toString m.transform},vrr,${toString m.vrr}"
            else "disable"
          }"
        ) (config.monitors)
      );

      #
      # ========== hy3 config ==========
      #
      #TODO enable this and config
      general.layout = "hy3";
      plugin = {
        hy3 = {
          enable = true;
        };
      };

      # Disable default background
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };
    };
    plugins = [
      pkgs.hyprlandPlugins.hy3
    ];
    extraConfig = ''
      ${builtins.readFile ../conf/hyprland.conf}
      ${builtins.readFile ../conf/hyprland-binds.conf}
    '';
    # gammastep/wallpaper-switcher need this to be enabled.
    systemd = {
      enable = true;
      variables = ["--all"];
    };
  };

  # NOTE: this executable is used by greetd to start a wayland session when system boot up
  # with such a vendor-no-locking script, we can switch to another wayland compositor without modifying greetd's config in NixOS module
  home.file.".wayland-session" = {
    source = "${package}/bin/Hyprland";
    executable = true;
  };

  # hyprland configs, based on https://github.com/notwidow/hyprland
  xdg.configFile = {
    "hypr/scripts" = {
      source = ../conf/scripts;
      recursive = true;
    };
    "hypr/waybar" = {
      source = ../conf/waybar;
      recursive = true;
    };
    "hypr/wlogout" = {
      source = ../conf/wlogout;
      recursive = true;
    };

    # music player - mpd
    "mpd" = {
      source = ../conf/mpd;
      recursive = true;
    };
  };
}
