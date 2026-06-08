{
  pkgs,
  config,
  lib,
  ...
}: let
  # Create script files for GameMode hooks
  gamemodeStartScript = pkgs.writeShellScript "gamemode-start" ''
    ${lib.optionalString config.services.power-profiles-daemon.enable ''
      # Save current power profile and switch to performance
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl get > /tmp/gamemode-power-profile
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance
    ''}
    ${lib.optionalString (config.services.asusd.enable or false) ''
      # Save current ASUS profile
      ${pkgs.asusctl}/bin/asusctl profile -p | grep "Active profile" | awk '{print $4}' > /tmp/gamemode-asus-profile

      # Set to Performance mode
      ${pkgs.asusctl}/bin/asusctl profile -P Performance
    ''}
  '';

  gamemodeEndScript = pkgs.writeShellScript "gamemode-end" ''
    ${lib.optionalString config.services.power-profiles-daemon.enable ''
      # Restore previous power profile
      PREVIOUS_POWER="balanced"
      if [ -f /tmp/gamemode-power-profile ]; then
        PREVIOUS_POWER=$(cat /tmp/gamemode-power-profile)
        rm /tmp/gamemode-power-profile
      fi
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set "$PREVIOUS_POWER"
    ''}
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
in {
  hardware.xone.enable = true;

  # Allow gamemode's privileged helpers to run without a polkit prompt.
  #
  # gamemode ships a polkit rule that grants members of the `gamemode` group
  # passwordless pkexec for its helpers:
  #   - gpuclockctl   — applies GPU clock/mem/fan offsets (gpu.* settings)
  #   - cpugovctl     — switches the CPU governor to `performance`
  #   - cpucorectl    — toggles SMT / per-core enable
  #   - procsysctl    — flips kernel sysctls (e.g. split_lock_mitigate)
  #
  # Without group membership these all fail with `pkexec: Not authorized`
  # and gamemode logs errors on every game launch. The user-space parts of
  # gamemode (renice, ioprio, SCHED_ISO, screensaver inhibit) work fine
  # without this — group membership only unlocks the root-gated helpers.
  users.users.${config.hostSpec.primaryUsername}.extraGroups = ["gamemode"];

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
            (pkgs.stdenv.cc.cc)
            lib
            ;

          inherit
            (pkgs)
            libxcursor
            libxi
            libxinerama
            libxscrnsaver
            libpng
            libpulseaudio
            libvorbis
            libkrb5
            keyutils
            gperftools
            ;
        });
      };

      extraCompatPackages = [
        pkgs.proton-ge-bin
        pkgs.proton-cachyos
      ];
    };
    # gamescope launch args set dynamically in home/<user>/common/optional/gaming
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
