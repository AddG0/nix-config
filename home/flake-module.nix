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

  # Create a simple placeholder that genUser can reference
  # The actual home configurations will be built by genUser with proper context
  homeConfigurations = builtins.listToAttrs (
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
          # Just a placeholder that indicates the config exists
          # genUser will build the actual configuration
          value = {
            _placeholder = true;
            user = user;
            hostFile = hostFile;
            configPath = ./. + "/${user}/${hostFile}";
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
