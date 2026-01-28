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

  environment.etc = {
    "1password/custom_allowed_browsers" = {
      text = ''
        zen
      '';
      mode = "0755";
    };
  };
}
