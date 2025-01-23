{
  pkgs,
  inputs,
  config,
  nix-secrets,
  lib,
  ...
}: let
  sopsHashedPasswordFile = lib.optionalString (!config.hostSpec.isMinimal) config.sops.secrets."passwords/${config.hostSpec.username}".path;

  userConfig = lib.custom.genUser {
    user = config.hostSpec.username;
    userDir = "primary";
    commonConfig = {
      environment.systemPackages = with pkgs; [
        just
        rsync
        git
      ];
    };
    linuxConfig = {
      users.users.${config.hostSpec.username} = {
        password = "nixos";
      };
    };
    pubKeys = lib.lists.forEach (lib.filesystem.listFilesRecursive ./keys) (key: builtins.readFile key);
  };
in {
  imports = [
    userConfig
  ];
}
