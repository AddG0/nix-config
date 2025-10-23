{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = lib.flatten [
    inputs.stylix.homeModules.stylix
    ./common

    (map lib.custom.relativeToHome [
      #################### Required Configs ####################
      "common/core" # required

      #################### Host-specific Optional Configs ####################
    ])
  ];
}
