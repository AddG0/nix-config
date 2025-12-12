{
  pkgs,
  config,
  lib,
  ...
}: let
  # Create script files for GameMode hooks
  gamemodeStartScript = pkgs.writeShellScript "gamemode-start" ''
    ${lib.optionalString (config.services.asusd.enable or false) ''
      # Save current ASUS profile
      ${pkgs.asusctl}/bin/asusctl profile -p | grep "Active profile" | awk '{print $4}' > /tmp/gamemode-asus-profile

      # Set to Performance mode
      ${pkgs.asusctl}/bin/asusctl profile -P Performance
    ''}
  '';

  gamemodeEndScript = pkgs.writeShellScript "gamemode-end" ''
    ${lib.optionalString (config.services.asusd.enable or false) ''
      # Restore previous ASUS profile
      PREVIOUS_PROFILE="Balanced"
      if [ -f /tmp/gamemode-asus-profile ]; then
        PREVIOUS_PROFILE=$(cat /tmp/gamemode-asus-profile)
        ${pkgs.asusctl}/bin/asusctl profile -P "$PREVIOUS_PROFILE"
        rm /tmp/gamemode-asus-profile
      fi
    ''}
  '';

  # Simple game wrapper - use in Steam launch options: game-wrapper %command%
  game-wrapper = pkgs.writeShellScriptBin "game-wrapper" ''
    exec ${pkgs.gamemode}/bin/gamemoderun "$@"
  '';
in {
  hardware.xone.enable = true;

  environment.systemPackages = [
    game-wrapper
  ];

  programs = {
    steam = {
      enable = true;
      protontricks = {
        enable = true;
      };

      gamescopeSession = {
        enable = true;
        args = [
          "--rt" # Use realtime scheduling
          "--expose-wayland" # Expose Wayland socket
          "--adaptive-sync" # Enable VRR/adaptive sync
          "--force-grab-cursor" # Better mouse capture for games
        ];
      };

      package = pkgs.steam.override {
        extraPkgs = pkgs: (builtins.attrValues {
          inherit
            (pkgs.xorg)
            libXcursor
            libXi
            libXinerama
            libXScrnSaver
            ;

          inherit
            (pkgs.stdenv.cc.cc)
            lib
            ;

          inherit
            (pkgs)
            libpng
            libpulseaudio
            libvorbis
            libkrb5
            keyutils
            gperftools
            ;
        });
      };

      extraCompatPackages = [pkgs.unstable.proton-ge-bin];
    };
    #gamescope launch args set dynamically in home/<user>/common/optional/gaming
    gamescope = {
      enable = true;
      capSysNice = true;
    };
    # to run steam games in game mode, add the following to the game's properties from within steam
    # gamemoderun %command%
    gamemode = {
      enable = true;
      settings = {
        # See gamemode man page for settings info
        general = {
          softrealtime = "on";
          inhibit_screensaver = 1;
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 1; # The DRM device number on the system (usually 0), ie. the number in /sys/class/drm/card0/
          # amd_performance_level only works for AMD GPUs, using custom scripts for NVIDIA instead
        };
        custom = {
          start = "${gamemodeStartScript}";
          end = "${gamemodeEndScript}";
        };
      };
    };
  };
}
