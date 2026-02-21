{
  pkgs,
  lib,
  nur-ryan4yin,
  config,
  ...
}: let
  package = pkgs.hyprland;

  transformToHyprland = {
    "normal" = 0;
    "90" = 1;
    "180" = 2;
    "270" = 3;
    "flipped" = 4;
    "flipped-90" = 5;
    "flipped-180" = 6;
    "flipped-270" = 7;
  };

  vrrToHyprland = {
    "off" = 0;
    "on" = 1;
    "fullscreen-only" = 2;
  };
in {
  wayland.windowManager.hyprland = {
    inherit package;
    enable = true;
    settings = {
      source = [
        "${nur-ryan4yin.packages.${pkgs.stdenv.hostPlatform.system}.catppuccin-hyprland}/themes/mocha.conf"
      ];
      env = [
        "NIXOS_OZONE_WL,1"
        "MOZ_ENABLE_WAYLAND,1"
        "MOZ_WEBRENDER,1"
        "_JAVA_AWT_WM_NONREPARENTING,1"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "QT_QPA_PLATFORM,wayland"
        "SDL_VIDEODRIVER,wayland"
        "GDK_BACKEND,wayland"
        "OGL_DEDICATED_HW_STATE_PER_CONTEXT,ENABLE_ROBUST"
        "WLR_NO_HARDWARE_CURSORS,1"
      ];

      cursor.no_hardware_cursors = true;

      # ========== Monitor ==========
      monitor =
        (map (
            m: "${m.name},${
              if m.enabled
              then "${toString m.width}x${toString m.height}@${toString m.refreshRate}.0,${toString m.x}x${toString m.y},1,transform,${toString transformToHyprland.${m.transform}},vrr,${toString vrrToHyprland.${m.vrr}}${
                if m.bitdepth != 8
                then ",bitdepth,${toString m.bitdepth}"
                else ""
              }${
                if m.hdr
                then ",cm,hdr"
                else ""
              }"
              else "disable"
            }"
          )
          config.monitors)
        ++ (lib.optional config.defaultMonitor.enable ",preferred,auto,1");

      # ========== Layout ==========
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 4;
      };

      # ========== Decoration ==========
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

      # ========== Animations ==========
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

      # ========== Dwindle ==========
      dwindle.pseudotile = false;

      # ========== Misc ==========
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      debug.disable_logs = false;

      # ========== Input ==========
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        mouse_refocus = false;
        natural_scroll = false;
        touchpad.natural_scroll = true;
        force_no_accel = false;
        numlock_by_default = true;
      };

      # ========== Variables ==========
      "$term" = "ghostty";
      "$browser" = "firefox";

      # ========== Window Rules ==========
      windowrule = [
        "float on, match:class ^(foot-float)$"
        "float on, match:class ^(yad|nm-connection-editor|pavucontrol)$"
        "float on, match:class ^(xfce-polkit|kvantummanager|qt5ct)$"
        "float on, match:class ^(feh|imv|Gpicview|Gimp|nomacs)$"
        "float on, match:class ^(VirtualBox Manager|qemu|Qemu-system-x86_64)$"
        "float on, match:class ^(xfce4-appfinder)$"
        "float on, match:title ^(foot-full)$"
        "move 0 0, match:title ^(foot-full)$"
        "size 100% 100%, match:title ^(foot-full)$"
        "float on, match:title ^(Select what to share)$"
        "pseudo on, match:class ^(fcitx)$"
        "workspace special silent, match:class ^(AWS VPN Client)$"
        "workspace special silent, match:title ^(BakkesModInjectorCpp)$"
        "workspace special silent, match:class ^(steam_app_252950)$, match:title ^$"
      ];

      # ========== Exec Once ==========
      exec-once = [
        "ln -sf $XDG_RUNTIME_DIR/hypr /tmp/hypr"
        "exec mpd"
        "cp ~/.config/fcitx5/profile-bak ~/.config/fcitx5/profile"
        "fcitx5 -d --replace"
      ];
    };
    plugins = [];
    systemd = {
      enable = true;
      variables = ["--all"];
    };
  };
}
