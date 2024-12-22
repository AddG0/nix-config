{
  user,
  commonConfig ? {},
  linuxConfig ? {},
  darwinConfig ? {},
  homeManagerConfig ? {},
  pubKeys ? [],
}: {
  pkgs,
  inputs,
  config,
  lib,
  ...
}: let
  hostSpec = config.hostSpec;
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;

  # Base user configuration common across all systems
  baseUserConfig = lib.recursiveUpdate commonConfig {
    users.users.${user} = {
      home = lib.mkIf (user != "root") (lib.custom.getHomeDirectory user);
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = pubKeys;
    };
    programs.zsh.enable = true;
    environment.systemPackages = with pkgs; [
      home-manager
    ];
  };

  # Linux-specific user configuration
  linuxUserConfig = lib.recursiveUpdate linuxConfig {
    users.users.${user} = {
      isNormalUser = lib.mkIf (user != "root") true;
      extraGroups =
        ["wheel"]
        ++ ifTheyExist [
          "audio"
          "video"
          "docker"
          "git"
          "networkmanager"
        ];
    };
  };

  # Darwin-specific user configuration
  darwinUserConfig = lib.recursiveUpdate darwinConfig {
    users.users.${user} = {
      name = user;
      home = lib.custom.getHomeDirectory user;
    };
  };

  # Home Manager configuration
  homeManagerUserConfig = lib.recursiveUpdate homeManagerConfig {
    home-manager = {
      extraSpecialArgs = {
        inherit pkgs inputs hostSpec;
        nix-secrets = inputs.nix-secrets;
        nur-ryan4yin = inputs.nur-ryan4yin;
      };
      users.${user} = {
        imports =
          if (!hostSpec.isMinimal)
          then [
            (import (lib.custom.relativeToRoot "home/${hostSpec.username}/${hostSpec.hostName}.nix") {
              inherit pkgs inputs config lib;
            })
          ]
          else [];
      };
    };
  };
in {
  imports = [
    # Convert each configuration to a module
    baseUserConfig
    (lib.mkIf pkgs.stdenv.isLinux linuxUserConfig)
    (lib.mkIf pkgs.stdenv.isDarwin darwinUserConfig)
    homeManagerUserConfig
  ];
}
