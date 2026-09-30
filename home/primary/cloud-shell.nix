# To test building: nix build .#homeConfigurations.cloud-shell.activationPackage --impure
{lib, ...}: {
  imports = lib.flatten [
    (with lib.custom.optional.home; [helper-scripts])
  ];

  # Override home configuration for cloud shell using environment variables
  home = let
    # Empty under pure eval (flake checks); setup-cloud-shell.sh runs --impure.
    envOr = name: fallback: let
      v = builtins.getEnv name;
    in
      if v == ""
      then fallback
      else v;
  in {
    username = lib.mkForce (envOr "USER" "cloudshell");
    homeDirectory = lib.mkForce (envOr "HOME" "/home/cloudshell");
    stateVersion = "24.05";
  };

  # Mark this as a server to avoid installing GUI tools
  hostSpec.hostType = lib.mkForce "server";
}
