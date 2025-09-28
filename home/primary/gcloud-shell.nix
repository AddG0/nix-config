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

  hostSpec = {
    username = "addg0_personal";
    hostName = "gcloud-shell";
    handle = "addg";
    isDarwin = false;
    isMinimal = true;
    disableSops = true;
  }

  programs.btop.enable = lib.mkForce true;
}
