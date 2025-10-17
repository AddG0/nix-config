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
        "browsers"
        "ghostty"
        # "nixos/desktops/plasma6"  # disabled for signage-only setup
        "helper-scripts"
      ])
    ))
  ];
  programs.btop.enable = lib.mkForce false;
}
