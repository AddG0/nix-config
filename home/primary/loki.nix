{
  config,
  inputs,
  pkgs,
  lib,
  hostSpec,
  desktops,
  ...
}: {
  imports = [
    inputs.stylix.homeModules.stylix

    #################### Required Configs ####################
    common/core # required

    #################### Host-specific Optional Configs ####################
    common/optional/nixos/desktops/hyprland
    common/optional/browsers
    common/optional/development/ide.nix
    common/optional/comms
    common/optional/ghostty
  ];
}
