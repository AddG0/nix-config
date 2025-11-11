{
  lib,
  config,
  ...
}: {
  imports = lib.flatten [
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

  # Override home configuration for cloud shell using environment variables
  home = {
    username = lib.mkForce (builtins.getEnv "USER");
    homeDirectory = lib.mkForce (builtins.getEnv "HOME");
    stateVersion = "24.05";
  };

  # Mark this as a server to avoid installing GUI tools
  hostSpec.isServer = lib.mkForce true;

  # Ensure basic utilities are available for shell initialization
  home.packages = with lib; [ pkgs.coreutils pkgs.gawk pkgs.gnused ];

  programs.btop.enable = lib.mkForce true;
}
