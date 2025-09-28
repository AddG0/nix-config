# home/flake-module.nix - Home-manager configuration discovery and exports
{
  self,
  inputs,
  lib,
  ...
}: let
  # Function to scan a directory and return all subdirectories
  getDirectories = path:
    if builtins.pathExists path
    then
      builtins.filter (
        name: let
          fullPath = path + "/${name}";
        in
          builtins.pathExists fullPath && (builtins.readFileType fullPath) == "directory"
      ) (builtins.attrNames (builtins.readDir path))
    else [];

  # Function to get all .nix files in a directory (these are the hostnames)
  getHostConfigs = userPath:
    if builtins.pathExists userPath
    then
      builtins.filter (
        name:
          builtins.match ".*\\.nix$" name
          != null
          && name != "default.nix" # exclude default.nix files
      ) (builtins.attrNames (builtins.readDir userPath))
    else [];

  # Get all user directories in home/
  userDirs = getDirectories ./.;

  # Function to get a simple mapping of what configurations exist
  getAvailableConfigs = builtins.listToAttrs (
    builtins.concatMap (
      user: let
        userPath = ./. + "/${user}";
        hostConfigs = getHostConfigs userPath;
      in
        builtins.map (hostFile: {
          name =
            if user == "primary"
            then builtins.replaceStrings [".nix"] [""] hostFile
            else "${user}@${builtins.replaceStrings [".nix"] [""] hostFile}";
          value = {
            user = user;
            host = builtins.replaceStrings [".nix"] [""] hostFile;
            path = ./. + "/${user}/${hostFile}";
          };
        })
        hostConfigs
    )
    userDirs
  );

  # Build actual home-manager configurations
  homeConfigurations = builtins.listToAttrs (
    builtins.concatMap (
      user: let
        userPath = ./. + "/${user}";
        hostConfigs = getHostConfigs userPath;
      in
        builtins.map (hostFile: let
          hostName = builtins.replaceStrings [".nix"] [""] hostFile;
          configName =
            if user == "primary"
            then hostName
            else "${user}@${hostName}";
          configPath = ./. + "/${user}/${hostFile}";
        in {
          name = configName;
          value = inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
            extraSpecialArgs = {
              inherit inputs;
              # Add common special args that home configs might need
              hostSpec = {
                hostName = hostName;
                username = user;
                # Default values that can be overridden
                isMinimal = false;
                system = {
                  stateVersion = "24.05";
                };
                home = "/home/${user}";
              };
              desktops = {};
              nix-secrets = inputs.nix-secrets;
              nur-ryan4yin = inputs.nur-ryan4yin;
            };
            modules = [
              configPath
              # Include any common modules
              {
                home = {
                  username = user;
                  homeDirectory = "/home/${user}";
                  stateVersion = "24.05";
                };
                programs.home-manager.enable = true;
              }
            ];
          };
        })
        hostConfigs
    )
    userDirs
  );
in {
  # Export as proper top-level flake outputs
  flake = {
    homeConfigurations = homeConfigurations;
  };

  # Also export metadata and helpers in legacyPackages
  perSystem = {
    config,
    pkgs,
    lib,
    ...
  }: {
    legacyPackages = {
      homeConfigurationMetadata = getAvailableConfigs;
      listHomeConfigurations = lib.attrNames getAvailableConfigs;
    };
  };
}
