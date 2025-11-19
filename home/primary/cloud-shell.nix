{lib, ...}: {
  imports = lib.flatten [
    ./common/core

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

  programs.btop.enable = lib.mkForce true;
}
