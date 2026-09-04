# Steam overlay missing in games: Steam → Settings → Interface → uncheck "Use GPU accelerated rendering in web views".
{
  config,
  osConfig ? null,
  inputs,
  pkgs,
  lib,
  ...
}: let
  razerEnabled = osConfig.hardware.openrazer.enable or false;
  defaultCompatTool = "GE-Proton";
  primaryMonitor = lib.findFirst (m: m.primary) null config.display.monitors;
  gamemoderun = lib.getExe' pkgs.gamemode "gamemoderun";

  # Game-only PRIME offload; the apps merge appends it innermost so gamescope
  # stays on the iGPU. Proton is Vulkan → NV optimus layer; DRI_PRIME for AMD.
  gpuOffload = let
    vendor = config.hostSpec.gpu.offload;
  in
    if vendor == null
    then []
    else
      ["env"]
      ++ {
        nvidia = [
          "__NV_PRIME_RENDER_OFFLOAD=1"
          "__NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0"
          "__GLX_VENDOR_LIBRARY_NAME=nvidia"
          "__VK_LAYER_NV_optimus=NVIDIA_only"
        ];
        amd = ["DRI_PRIME=1"];
      }
      .${
        vendor
      };

  # hyprctl of the running compositor — reused from its closure, no second copy.
  hyprctl = lib.getExe' config.wayland.windowManager.hyprland.package "hyprctl";
  isLaptop = config.hostSpec.hostType == "laptop";
  hdrArgs = lib.optionals (primaryMonitor.hdr or false) ["--hdr-enabled"];

  mkGamescope = import ./gamescope.nix {
    inherit lib pkgs hyprctl isLaptop primaryMonitor hdrArgs;
    monitors = config.display.monitors;
  };
  gamescope = mkGamescope {};

  mouseDpi = import ./mouse-dpi.nix {inherit lib pkgs razerEnabled;};

  # `or false`: hosts without gaming/bakkesmod.nix have no such option at all.
  bakkesLauncher = lib.optional (config.programs.bakkesmod.enable or false) config.programs.bakkesmod.launcherPackage;

  # name → Steam appid.
  defaults =
    lib.mapAttrs (_: id: {
      inherit id;
      wrappers = [gamemoderun];
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
      cyberpunk-2077 = 1091500;

      # VR
      bigscreen-beyond-utility = 2467050;
    };

  # Per-game overrides merged over defaults.
  overrides = {
    # Rocket League has a linux build, but it's not maintained so we need to use the windows version
    rocket-league.compatTool = defaultCompatTool;
    # Inert unless Steam's "Anti-Cheat Disabled" launch option is selected — a
    # manual choice; BakkesMod cannot inject into the EAC executable.
    rocket-league.wrappers = [gamemoderun] ++ bakkesLauncher;
    # I had multiplayer issues with the linux version. So I'm using the windows version.
    portal-2.compatTool = defaultCompatTool;
    # Wouldn't let me install if this wasn't set
    conan-exiles.compatTool = defaultCompatTool;
    # Was not opening with linux version
    aimlabs.compatTool = defaultCompatTool;

    # Gamescope wrap: HZD's native fullscreen on Linux/Proton is broken
    # (wrong resolution, multi-monitor misbehavior, alt-tab loss).
    # Gamescope forces a sane fullscreen surface and fixes it.
    horizon-zero-dawn.wrappers = [gamemoderun] ++ gamescope;

    aimlabs.wrappers = mouseDpi 1600 ++ [gamemoderun];

    # Wrap in gaemscope to fix weird fullscreen behavior
    forza-horizon-4.wrappers = [gamemoderun] ++ gamescope;
    forza-horizon-5.wrappers = [gamemoderun] ++ gamescope;
    forza-horizon-6.wrappers = [gamemoderun] ++ gamescope;

    overwatch.wrappers = mouseDpi 1800 ++ [gamemoderun];

    # 2000 DPI + in-game sens 2 reproduces the Aim Lab cm/360 (0.52% off).
    cyberpunk-2077.wrappers = mouseDpi 2000 ++ [gamemoderun];

    # Bigscreen Beyond Utility — Windows-only app for adjusting the
    # headset's fan, brightness, refresh rate, and LED color.
    # Intentionally minimal: PROTON_ENABLE_HIDRAW is documented but
    # appears to make things worse on Proton 10.x / Experimental
    # (BeyondHID logs "parent not found" with it set). The first
    # successful detection at 14:06 happened with no override at all.
    # https://github.com/ValveSoftware/Proton/issues/8672
  };
in {
  imports = [
    inputs.steam-config-nix.homeModules.default
  ];

  programs.steam.config = {
    enable = true;
    onSteamRunning = "close";
    inherit defaultCompatTool;
    # steam-config-nix keys apps by app ID; the slug lives on as `name` (desktop
    # entry / systemd target), so the tables above stay readable.
    apps = lib.mapAttrs' (name: app:
      lib.nameValuePair (toString app.id) (
        lib.recursiveUpdate app {
          inherit name;
          wrappers = (app.wrappers or []) ++ gpuOffload;
        }
      ))
    (lib.recursiveUpdate defaults overrides);
  };

  # Enable multi-threaded Vulkan shader compilation for Steam
  # By default Steam uses only 1 thread, causing slow shader processing
  #
  # NOTE: You must also enable "Allow background processing of Vulkan shaders"
  # in Steam → Settings → Downloads. This setting can only be toggled via GUI,
  # not via config files (it's stored in config.vdf which Steam manages internally).
  # Not ~/.steam/steam: home-manager would create that as a real directory,
  # squatting the path Steam symlinks on first run — "Couldn't set up Steam data".
  home.file.".local/share/Steam/steam_dev.cfg".text = ''
    unShaderBackgroundProcessingThreads 1
  '';

  # Decky Loader injects its UI via Steam's CEF debugger (port 8080); this
  # marker enables it. Requires a full Steam restart after first creation.
  home.file.".local/share/Steam/.cef-enable-remote-debugging".text = "";

  wayland.windowManager.hyprland.settings.windowrule =
    [
      # Steam maps this dialog as a normal window, so it tiles full-height.
      "float on, match:class ^([Ss]team)$, match:title ^(Authorize Device)$"
      "center 1, match:class ^([Ss]team)$, match:title ^(Authorize Device)$"
      "float on, match:title ^(ProtonFixes)$"
      # Terraria's blank launcher helper.
      "workspace special silent, match:class ^(steam_app_252950)$, match:title ^$"
      "workspace special silent, match:title (Lethal Company.*\\.exe)"
    ]
    # Steam toasts ignore the X11 primary; pin them to the primary's corner.
    # Without "silent" the toast mapping there drags the cursor along with it.
    ++ lib.optionals (primaryMonitor != null) [
      "float on, match:title ^(notificationtoasts.*)$"
      "monitor ${primaryMonitor.output} silent, match:title ^(notificationtoasts.*)$"
      "move 100%-w-20 100%-h-20, match:title ^(notificationtoasts.*)$"
    ];
}
