{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.stylix.homeModules.stylix

    #################### Required Configs ####################
    common/core # required

    #################### Host-specific Optional Configs ####################
  ];
}
