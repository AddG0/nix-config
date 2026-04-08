{
  pkgs,
  lib,
  config,
  ...
}: let
  package = pkgs.hyprland;

  hyprLib = import ./lib.nix;
  transformToHyprland = hyprLib.transformMap;
  vrrToHyprland = hyprLib.vrrMap;
in {
  wayland.windowManager.hyprland = {
    inherit package;
    enable = true;
    settings = {
      env = [
        "NIXOS_OZONE_WL,1"
        "MOZ_ENABLE_WAYLAND,1"
        "MOZ_WEBRENDER,1"
        "_JAVA_AWT_WM_NONREPARENTING,1"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "QT_QPA_PLATFORM,wayland"

        "GDK_BACKEND,wayland"
        "OGL_DEDICATED_HW_STATE_PER_CONTEXT,ENABLE_ROBUST"
        "XCURSOR_SIZE,${toString config.stylix.cursor.size}"
      ];

      # ========== Monitor ==========
      monitor =
        (map (
            m: "${m.name},${
              if m.enabled
              then "${toString m.width}x${toString m.height}@${toString m.refreshRate}.0,${toString m.x}x${toString m.y},${toString m.scale},transform,${toString transformToHyprland.${m.transform}},vrr,${toString vrrToHyprland.${m.vrr}}${
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
      };

      # ========== Dwindle ==========
      dwindle.pseudotile = false;

      # ========== Misc ==========
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      debug.disable_logs = true;

      # ========== Input ==========
      input = {
        kb_layout = "us";
        kb_options = "caps:escape";
        follow_mouse = 1;
        mouse_refocus = false;
        natural_scroll = false;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
        };
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
        "workspace special silent, match:class ^(AWS VPN Client)$"
        "float on, match:title ^(ProtonFixes)$"
        "float on, match:title ^(BakkesModInjectorCpp)$"
        "workspace special silent, match:title ^(BakkesModInjectorCpp)$"
        "workspace special silent, match:class ^(steam_app_252950)$, match:title ^$"
        "workspace special silent, match:title (Lethal Company.*\\.exe)"
        "workspace special silent, match:class ^(me\\.kavishdevar\\.librepods|librepods|applinux)$"
        "float on, match:class ^(me\\.kavishdevar\\.librepods|librepods|applinux)$"
        # Spotify — float on special workspace, centered at a comfortable size
        "workspace special silent, match:class ^(Spotify|spotify)$"
        "float on, match:class ^(Spotify|spotify)$"
        "size 60% 44%, match:class ^(Spotify|spotify)$"
        "center 1, match:class ^(Spotify|spotify)$"
      ];

      # ========== Exec Once ==========
      exec-once = [
      ];
    };
    plugins = [];
    systemd = {
      enable = false; # UWSM handles session management
    };
  };
}
