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
  primaryMonitor = lib.findFirst (m: m.primary) null config.display.monitors;
in {
  wayland.windowManager.hyprland = {
    inherit package;
    enable = true;
    # Hyprland 0.55 added a Lua config backend, and home-manager defaults
    # configType to "lua" for stateVersion >= 26.05 (ours is "26.05"). Our
    # whole config — including the hy3 binds — is written in hyprlang, so
    # pin the backend to hyprlang to keep writing hyprland.conf.
    configType = "hyprlang";
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
      ];

      # ========== Monitor ==========
      monitor =
        (map (
            m: "${m.output},${
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
          config.display.monitors)
        ++ (lib.optional config.display.defaultMonitor.enable ",preferred,auto,1");

      # ========== Layout ==========
      general = {
        gaps_in = 5;
        gaps_out = 10;
      };

      # ========== Misc ==========
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      debug.disable_logs = false;

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
        # IntelliJ / JetBrains (splash leaks the coroutine class)
        "float on, match:class ^(jetbrains-idea)$, match:title ^(IntelliJ IDEA User Agreement)$"
        "float on, match:class ^(kotlinx-coroutines-scheduling-CoroutineScheduler\\$Worker)$"
        "workspace special silent, match:title ^(Gateway to .*)$"
        "float on, match:title ^(foot-full)$"
        "move 0 0, match:title ^(foot-full)$"
        "size 100% 100%, match:title ^(foot-full)$"
        "float on, match:title ^(Select what to share)$"
        "workspace special silent, match:class ^(AWS VPN Client)$"
        "float on, match:title ^(ProtonFixes)$"
        "workspace special silent, match:class ^(steam_app_252950)$, match:title ^$"
        # Steam updater dialog: XWayland window comes up with an empty class
        # and title "Steam", so the main `^([Ss]team)$` class rule misses it.
        "workspace 6 silent, match:class ^$, match:title ^Steam$"
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
      # Set the X11 primary monitor so the Steam overlay picks the right
      # output/scale.
      exec-once =
        lib.optional (primaryMonitor != null)
        "${lib.getExe pkgs.xrandr} --output ${primaryMonitor.output} --primary";
    };
    plugins = [];
    systemd = {
      enable = false; # UWSM handles session management
    };
  };

  # systemd user-manager environment for cursor.
  #
  # Stylix sets XCURSOR_THEME/XCURSOR_SIZE via home.sessionVariables, but
  # that only reaches shell sessions — systemd user services (e.g.
  # app-steam@autostart) start before UWSM finalizes those vars into the
  # user manager, so they inherit a stripped env and apps render with the
  # XWayland default (48px) cursor. systemd reads ~/.config/environment.d/*.conf
  # at user-manager startup, before any user service runs, so seeding the
  # cursor vars here is the earliest point in the boot ordering they can
  # land. Hyprland itself is a systemd user unit under UWSM, so it picks
  # these up too — no need to also set them in wayland.windowManager.env.
  #
  # HYPRCURSOR_* intentionally not set: Bibata is xcursor-only, and pointing
  # HYPRCURSOR_THEME at a non-hyprcursor theme caused inconsistent sizing
  # on native Wayland apps.
  xdg.configFile."environment.d/10-cursor.conf".text = ''
    XCURSOR_THEME=${config.stylix.cursor.name}
    XCURSOR_SIZE=${toString config.stylix.cursor.size}
  '';
}
