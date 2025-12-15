{
  config,
  pkgs,
  lib,
  ...
}: {
  programs._1password.enable = true;
  programs._1password-gui =
    {
      enable = true;
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      polkitPolicyOwners = [config.hostSpec.username];
    };

  users.users.${config.hostSpec.username}.extraGroups = lib.mkIf pkgs.stdenv.isLinux ["onepassword-cli"];
}
