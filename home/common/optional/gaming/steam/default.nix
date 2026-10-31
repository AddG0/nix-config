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
  gameOutput = import ./game-output.nix {
    inherit lib pkgs hyprctl primaryMonitor;
    inherit (config.display) monitors;
  };
  mkGamescope = import ./gamescope.nix {inherit lib pkgs;};
  gamescope = mkGamescope {hdr = false;} [];
  gamescopeHdr = mkGamescope {hdr = true;} [];
  gameDefaults = import ./game-defaults.nix {inherit lib pkgs gameOutput gamemoderun gamescope gpuOffload;};

  mouseDpi = import ./mouse-dpi.nix {inherit lib pkgs razerEnabled;};

  # `or false`: hosts without gaming/rocket-league.nix have no such option at all.
  bakkesLauncher = lib.optional (config.programs.bakkesmod.enable or false) config.programs.bakkesmod.launcherPackage;

  requireController = import ./require-controller.nix {inherit lib pkgs;};

  ids = import ./ids.nix;
  settings = import ./games.nix {inherit defaultCompatTool gamemoderun gamescope gamescopeHdr mouseDpi requireController bakkesLauncher;};
  unknownSlugs = lib.attrNames (removeAttrs settings (lib.attrNames ids));
  games =
    if unknownSlugs != []
    then throw "steam/games.nix: no app ID in steam/ids.nix for ${lib.concatStringsSep ", " unknownSlugs}"
    else lib.recursiveUpdate (lib.mapAttrs (_: id: {inherit id;}) ids) settings;
in {
  imports = [
    inputs.steam-config-nix.homeModules.default
    ./hyprland.nix
    {
      options.programs.steam.config.apps = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submoduleWith {
          modules = [
            {
              options.keepHdr = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Keep an HDR monitor in HDR while this SDR game is fullscreen, instead of a desktop switching it to SDR.";
              };
            }
          ];
        });
      };
    }
  ];

  programs.steam.config = {
    enable = true;
    onSteamRunning = "close";
    inherit defaultCompatTool;
    # steam-config-nix keys apps by app ID; the slug lives on as `name` (desktop
    # entry / systemd target), so ids.nix and games.nix stay readable.
    apps = lib.mapAttrs' (name: app:
      lib.nameValuePair (toString app.id) (
        lib.recursiveUpdate app {
          inherit name;
          wrappers = [gameOutput] ++ (app.wrappers or [gamemoderun]) ++ gpuOffload;
        }
      ))
    games;
  };

  home.packages = [gameDefaults];

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
}
