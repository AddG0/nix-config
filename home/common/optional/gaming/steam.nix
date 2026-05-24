# Steam overlay missing in games: Steam → Settings → Interface → uncheck "Use GPU accelerated rendering in web views".
{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  defaultCompatTool = "GE-Proton";
  primaryMonitor = lib.findFirst (m: m.primary) null config.display.monitors;
  gamemoderun = lib.getExe' pkgs.gamemode "gamemoderun";

  # Gamescope preconfigured for the primary monitor's native resolution.
  # Opt in per-game by spreading into wrappers:
  #   launchOptions.wrappers = [gamemoderun] ++ gamescope;
  # Skip for: anti-cheat games (EAC), games where Steam overlay must work,
  # games run via PROTON_ENABLE_WAYLAND=1, and titles you want to tile freely.
  gamescope = [
    (lib.getExe pkgs.gamescope)
    "-W"
    (toString primaryMonitor.width)
    "-H"
    (toString primaryMonitor.height)
    "-w"
    (toString primaryMonitor.width)
    "-h"
    (toString primaryMonitor.height)
    "-r"
    (toString primaryMonitor.refreshRate)
    "-f"
    "--"
  ];

  # name → Steam appid. Each game gets a default config of
  # `{ id; launchOptions.wrappers = [gamemoderun]; }`; per-game overrides
  # are merged below.
  defaults =
    lib.mapAttrs (_: id: {
      inherit id;
      launchOptions.wrappers = [gamemoderun];
    }) {
      rocket-league = 252950;
      satisfactory = 526870;
      ark-survival-ascended = 2399830;
      conan-exiles = 440900;
      repo = 3241660;
      lethal-company = 1966720;
      subnautica-2 = 1962700;
      phasmophobia = 739630;
      overwatch = 2357570;
      horizon-zero-dawn = 2561580; # Remastered. Use 1151640 for original Complete Edition.
      avatar-frontiers-of-pandora = 2840770;
      escape-simulator = 1435790;
      escape-simulator-2 = 2879840;
      forza-horizon-4 = 1293830;
      forza-horizon-5 = 1551360;
      forza-horizon-6 = 2483190;
      tmodloader = 1281930;
      terraria = 105600;
      terratech = 285920;
      subnautica = 264710;
      subnautica-below-zero = 848450;
      scrap-mechanic = 387990;
      bloons-td-6 = 960090;
      split-fiction = 2001120;
      schedule-1 = 3164500;
      marvel-rivals = 2767030;
      ultrakill = 1229490;
      trackmania = 2225070;
      it-takes-two = 1426210;
      aimlabs = 714010;
      portal-2 = 620;
      fps-chess = 2021910;
    };
in {
  imports = [
    inputs.steam-config-nix.homeModules.default
  ];

  programs.steam.config = {
    enable = true;
    closeSteam = true;
    inherit defaultCompatTool;
    apps = lib.recursiveUpdate defaults {
      # Rocket League has a linux build, but it's not maintained so we need to use the windows version
      rocket-league.compatTool = defaultCompatTool;

      # I had multiplayer issues with the linux version. So I'm using the windows version.
      portal-2.compatTool = defaultCompatTool;

      # Gamescope wrap: HZD's native fullscreen on Linux/Proton is broken
      # (wrong resolution, multi-monitor misbehavior, alt-tab loss).
      # Gamescope forces a sane fullscreen surface and fixes it.
      horizon-zero-dawn.launchOptions.wrappers = [gamemoderun] ++ gamescope;
    };
  };

  # Enable multi-threaded Vulkan shader compilation for Steam
  # By default Steam uses only 1 thread, causing slow shader processing
  #
  # NOTE: You must also enable "Allow background processing of Vulkan shaders"
  # in Steam → Settings → Downloads. This setting can only be toggled via GUI,
  # not via config files (it's stored in config.vdf which Steam manages internally).
  home.file.".steam/steam/steam_dev.cfg".text = ''
    unShaderBackgroundProcessingThreads 1
  '';
}
