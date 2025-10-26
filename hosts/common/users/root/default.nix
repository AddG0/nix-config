{
  pkgs,
  config,
  ...
}: let
  inherit (config) hostSpec;
in {
  # root's ssh key are mainly used for remote deployment, borg, and some other specific ops
  users.users.root = {
    shell = pkgs.zsh;
    inherit (config.users.users.${hostSpec.username}) hashedPasswordFile;
    inherit (config.users.users.${hostSpec.username}) hashedPassword; # This comes from hosts/common/optional/minimal.nix and gets overridden if sops is working
    openssh.authorizedKeys.keys = config.users.users.${hostSpec.username}.openssh.authorizedKeys.keys; # root's ssh keys are mainly used for remote deployment.
  };
}
