{pkgs, config, lib, ...}: let
  # Create script files for GameMode hooks
  gamemodeStartScript = pkgs.writeShellScript "gamemode-start" ''
    # Save current power profile
    ${pkgs.power-profiles-daemon}/bin/powerprofilesctl get > /tmp/gamemode-power-profile
    # Set to performance mode
    ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance
    # Notify user with nice formatting
    ${pkgs.libnotify}/bin/notify-send \
      --app-name="GameMode" \
      --icon=applications-games \
      --urgency=normal \
      --expire-time=3000 \
      "🎮 GameMode Activated" \
      "System: Performance Profile"
  '';

  gamemodeEndScript = pkgs.writeShellScript "gamemode-end" ''
    # Restore previous power profile
    PREVIOUS_PROFILE="balanced"
    if [ -f /tmp/gamemode-power-profile ]; then
      PREVIOUS_PROFILE=$(cat /tmp/gamemode-power-profile)
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set "$PREVIOUS_PROFILE"
      rm /tmp/gamemode-power-profile
    fi
    # Notify user with nice formatting
    ${pkgs.libnotify}/bin/notify-send \
      --app-name="GameMode" \
      --icon=application-exit \
      --urgency=low \
      --expire-time=3000 \
      "🎮 GameMode Deactivated" \
      "Restored to $PREVIOUS_PROFILE mode"
  '';
in {
  hardware.xone.enable = true; # xbox controller

  programs = {
    steam = {
      enable = true;
      # protontricks = {
      #   enable = true;
      # };
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
