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

  # Get all user directories in home/ - cached once
  userDirs = getDirectories ./.;

  # Cache user configs mapping to avoid rescanning
  userConfigsMap = builtins.listToAttrs (
    map (user: {
      name = user;
      value = {
        path = ./. + "/${user}";
        configs = getHostConfigs (./. + "/${user}");
      };
    })
    userDirs
  );

  # Extend lib once and reuse - significant performance improvement
  extendedLib = inputs.nixpkgs.lib.extend (_self: _super: {
    custom = import ../lib/default.nix {inherit (inputs.nixpkgs) lib;};
    inherit (inputs.home-manager.lib) hm;
  });

  # Function to get a simple mapping of what configurations exist
  getAvailableConfigs = builtins.listToAttrs (
    builtins.concatMap (
      user: let
        userInfo = userConfigsMap.${user};
      in
        builtins.map (hostFile: {
          name =
            if user == "primary"
            then builtins.replaceStrings [".nix"] [""] hostFile
            else "${user}@${builtins.replaceStrings [".nix"] [""] hostFile}";
          value = {
            inherit user;
            host = builtins.replaceStrings [".nix"] [""] hostFile;
            path = userInfo.path + "/${hostFile}";
          };
        })
        userInfo.configs
    )
    userDirs
  );

  # Build actual home-manager configurations
  homeConfigurations = builtins.listToAttrs (
    builtins.concatMap (
      user: let
        userInfo = userConfigsMap.${user};
      in
        builtins.map (hostFile: let
          hostName = builtins.replaceStrings [".nix"] [""] hostFile;
          configName =
            if user == "primary"
            then hostName
            else "${user}@${hostName}";
          configPath = userInfo.path + "/${hostFile}";
        in {
          name = configName;
          value = inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
            extraSpecialArgs = {
              inherit inputs self;
              # Use the shared extended lib
              lib = extendedLib;
              # Provide basic hostSpec - modules can override specific values
              hostSpec = {
                inherit hostName;
                username = user;
                handle = user;
                home = "/home/${user}";
                isMinimal = false;
                hostType = "desktop";
                isDarwin = false;
                disableSops = true;
                hostPlatform = "x86_64-linux";
                system = {
                  stateVersion = "24.05";
                };
                domain = "example.com";
                email = {
                  personal = "user@example.com";
                  work = "user@work.example.com";
                };
                userFullName = "Example User";
                githubEmail = "user@example.com";
                networking = {
                  prefixLength = 24;
                  ports.tcp.ssh = 22;
                  ssh = {
                    extraConfig = "";
                  };
                  hostsAddr = {};
                };
              };
              desktops = {};
              inherit (inputs) nix-secrets;
              inherit (inputs) nur-ryan4yin;
            };
            modules = [
              # Pass the extended lib to modules
              {
                _module.args.lib = extendedLib;
              }
              configPath
            ];
          };
        })
        userInfo.configs
    )
    userDirs
  );
in {
  # Export as proper top-level flake outputs
  flake = {
    inherit homeConfigurations;
  };

  # Also export metadata and helpers in legacyPackages
  perSystem = {lib, ...}: {
    legacyPackages = {
      homeConfigurationMetadata = getAvailableConfigs;
      listHomeConfigurations = lib.attrNames getAvailableConfigs;
    };
  };
}
