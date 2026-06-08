# To test building: nix build .#homeConfigurations.cloud-shell.activationPackage --impure
{lib, ...}: {
  imports = lib.flatten [
    (map lib.custom.relativeToHome (map (f: "common/optional/${f}") [
      "helper-scripts"
    ]))
  ];

  # Override home configuration for cloud shell using environment variables
  home = {
    username = lib.mkForce (builtins.getEnv "USER");
    homeDirectory = lib.mkForce (builtins.getEnv "HOME");
    stateVersion = "24.05";
  };

  # Mark this as a server to avoid installing GUI tools
  hostSpec.hostType = lib.mkForce "server";
}
