{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  transformToNiri = {
    "normal" = {};
    "90" = {rotation = 90;};
    "180" = {rotation = 180;};
    "270" = {rotation = 270;};
    "flipped" = {flipped = true;};
    "flipped-90" = {
      rotation = 90;
      flipped = true;
    };
    "flipped-180" = {
      rotation = 180;
      flipped = true;
    };
    "flipped-270" = {
      rotation = 270;
      flipped = true;
    };
  };
in {
  imports = [
    inputs.noctalia.homeModules.default
    ./binds.nix
  ];

  #
  # ========== Niri compositor ==========
  #
  programs.niri.settings = {
    #
    # ---- Outputs (from config.monitors) ----
    #
    outputs = builtins.listToAttrs (
      map (m: {
        inherit (m) name;
        value =
          if !m.enabled
          then {enable = false;}
          else {
            mode = {
              inherit (m) width height;
              refresh = m.refreshRate * 1.0;
            };
            inherit (m) scale;
            transform = transformToNiri.${m.transform};
            position = {
              inherit (m) x y;
            };
            variable-refresh-rate = m.vrr != "off";
          };
      })
      config.monitors
    );

    #
    # ---- Input ----
    #
    input.keyboard.xkb = {
      layout = "us";
      options = "caps:escape";
    };

    input.mouse = {
      accel-profile = "flat"; # no acceleration
    };

    input.touchpad = {
      tap = true;
      natural-scroll = true;
    };

    # Ask apps to omit client-side title bars
    prefer-no-csd = true;

    # Use niri-flake's unstable build for fixes beyond 0.8 (e.g. Steam spawn issue)
    xwayland-satellite.path = "${inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.xwayland-satellite-unstable}/bin/xwayland-satellite";

    #
    # ---- Environment ----
    #
    environment = {
      "ELECTRON_OZONE_PLATFORM_HINT" = "wayland"; # Electron apps (Slack, Discord, VS Code) use native Wayland
    };

    #
    # ---- Layout ----
    #
    layout = {
      gaps = 8;

      center-focused-column = "never";

      preset-column-widths = [
        {proportion = 1.0 / 3.0;}
        {proportion = 1.0 / 2.0;}
        {proportion = 2.0 / 3.0;}
      ];

      default-column-width = {proportion = 1.0 / 2.0;};

      focus-ring = {
        enable = true;
        width = 2;
        active.color = "#7fc8ff";
        inactive.color = "#505050";
      };

      border.enable = false;
    };

    #
    # ---- Startup ----
    #
    spawn-at-startup = [
      {argv = ["noctalia-shell"];}
      {argv = ["${pkgs.swayidle}/bin/swayidle" "-w"];}
    ];

    #
    # ---- Window rules ----
    #
    # Rounded corners for Noctalia
    window-rules = [
      {
        geometry-corner-radius = let
          r = 12.0;
        in {
          top-left = r;
          top-right = r;
          bottom-left = r;
          bottom-right = r;
        };
        clip-to-geometry = true;
      }
    ];
  };

  #
  # ========== Noctalia shell ==========
  #
  programs.noctalia-shell = {
    enable = true;
    settings = {
      bar.position = "top";
      bar.widgets.right = [
        {id = "Tray";}
        {id = "Microphone";}
        {id = "NotificationHistory";}
        {id = "Volume";}
        {id = "ControlCenter";}
      ];
      # Show notifications only on the primary monitor
      notifications.monitors = map (m: m.name) (builtins.filter (m: m.primary) config.monitors);
      location.useFahrenheit = true;
      location.use12hourFormat = true;
      colorSchemes.predefinedScheme = "Catppuccin";
      general.avatarImage = "/var/lib/AccountsService/icons/${config.home.username}";
    };
  };

  home.file.".cache/noctalia/wallpapers.json".text = builtins.toJSON {
    defaultWallpaper = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Nexus/contents/images_dark/5120x2880.png";
  };
}
