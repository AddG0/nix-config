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
  ];
}