{
  config,
  inputs,
  pkgs,
  lib,
  hostSpec,
  desktops,
  ...
}: {
  imports = lib.flatten [
    inputs.stylix.homeModules.stylix
    ./common

    (map lib.custom.relativeToHome (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "helper-scripts"
      ])
    ))
  ];

  # Override home configuration for cloud shell
  home = {
    username = lib.mkForce "addg0_personal";
    homeDirectory = lib.mkForce "/home/addg0_personal";
    stateVersion = "24.05";
  };

  programs.btop.enable = lib.mkForce true;
}
