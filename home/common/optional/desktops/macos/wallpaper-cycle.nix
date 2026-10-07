# macOS counterpart of the Linux wpaperd rotation: a random image from the
# shared wallhaven set on every display, every 30 minutes.
{
  config,
  lib,
  pkgs,
  ...
}: let
  label = "local.wallpaper-cycle";
  images = pkgs.linkFarm "wallhaven-wallpapers" (import ../_wallhaven.nix {inherit pkgs;});

  cycle = pkgs.writeShellApplication {
    name = "wallpaper-cycle";
    runtimeInputs = [pkgs.desktoppr pkgs.coreutils];
    text = ''
      image=$(shuf -n 1 -e ${images}/*)
      echo "$(date -Iseconds) $image"
      desktoppr all "$image"
    '';
  };

  agent = pkgs.writeText "${label}.plist" (lib.generators.toPlist {escape = true;} {
    Label = label;
    ProgramArguments = ["${config.home.profileDirectory}/bin/wallpaper-cycle"];
    RunAtLoad = true;
    StartInterval = 30 * 60;
    LimitLoadToSessionType = "Aqua";
    StandardOutPath = "${config.home.homeDirectory}/Library/Logs/${label}.log";
    StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/${label}.log";
  });
in {
  assertions = [(lib.hm.assertions.assertPlatform "desktops.macos.wallpaper-cycle" pkgs lib.platforms.darwin)];

  home.packages = [cycle];

  home.activation.wallpaperCycle = lib.hm.dag.entryAfter ["linkGeneration"] (lib.custom.darwinGuiAgentActivation {
    inherit label;
    plist = agent;
  });
}
