# niri-flake on every host, so home modules can set `programs.niri.*` ungated; the niri suite enables it.
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [inputs.niri.nixosModules.niri];

  # Every host: home settings reference the package even where niri is off.
  # FLAKE-UPDATE: drop once niri-flake's niri-stable builds against our nixpkgs;
  # its 2026-08-04 pin still asks for the removed libdisplay-info_0_2.
  programs.niri.package = pkgs.niri;

  # Serves only niri-flake's own builds, and we run nixpkgs' niri.
  niri-flake.cache.enable = false;

  # niri-flake writes config.kdl whenever settings exist; tie it to the system enable, as Hyprland's is.
  home-manager.sharedModules = [
    {xdg.configFile.niri-config.enable = lib.mkIf (!config.programs.niri.enable) (lib.mkForce false);}
  ];
}
