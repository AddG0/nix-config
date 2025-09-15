{
  pkgs,
  inputs,
  config,
  nix-secrets,
  lib,
  ...
}: let
  sopsHashedPasswordFile = lib.optionalString (!config.hostSpec.isMinimal) config.sops.secrets."password".path;

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
    linuxConfig = if (config.hostSpec.disableSops == false) then {
      users.users.${config.hostSpec.username} = {
        hashedPasswordFile = sopsHashedPasswordFile;
      };
    } else {};
    pubKeys = lib.lists.forEach (lib.filesystem.listFilesRecursive ./keys) (key: builtins.readFile key);
  };
in {
  imports = [
    userConfig
  ];
}
