{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.stylix.homeManagerModules.stylix

    #################### Required Configs ####################
    common/core # required

    #################### Host-specific Optional Configs ####################
  ];

  home = {
    username = config.hostSpec.username;
    homeDirectory = lib.custom.getHomeDirectory config.hostSpec.username;
  };
}
