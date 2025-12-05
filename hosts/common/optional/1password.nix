{
  config,
  pkgs,
  lib,
  ...
}: {
  programs._1password.enable = true;
  programs._1password-gui = lib.mkMerge [
    {enable = true;}
    (lib.mkIf pkgs.stdenv.isLinux {
      # Certain features, including CLI integration and system authentication support,
      # require enabling PolKit integration on some desktop environments (e.g. Plasma).
      polkitPolicyOwners = [config.hostSpec.username];
    })
  ];
}
