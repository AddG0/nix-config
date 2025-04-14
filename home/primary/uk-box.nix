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
    common/optional/helper-scripts
    common/optional/jupyter-notebook
  ];

  home = {
    username = config.hostSpec.username;
    homeDirectory = lib.custom.getHomeDirectory config.hostSpec.username;
  };
}
