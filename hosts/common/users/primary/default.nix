{
  pkgs,
  config,
  lib,
  ...
}: let
  # Only set hashedPasswordFile when sops is enabled and not minimal
  useSopsPassword = !config.hostSpec.disableSops && !config.hostSpec.isMinimal;

  userConfig = lib.custom.genUser {
    user = config.hostSpec.username;
    userDir = "primary";
    commonConfig = {
      environment.systemPackages = with pkgs; [
        just
        rsync
      ];
    };
    linuxConfig = {
      users.users.${config.hostSpec.username} =
        {
          uid = 1000;
        }
        // lib.optionalAttrs useSopsPassword {
          hashedPasswordFile = config.sops.secrets."password".path;
        }
        // lib.optionalAttrs (!useSopsPassword) {
          initialPassword = "changeme";
        };
    };
    pubKeys = lib.lists.forEach (lib.filesystem.listFilesRecursive ./keys) (key: builtins.readFile key);
  };
in {
  imports = [
    userConfig
  ];
}
