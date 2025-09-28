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

  # Function to determine system architecture for a host
  getSystemForHost = hostName: let
    nixosHostExists = builtins.pathExists (../hosts/nixos + "/${hostName}");
    darwinHostExists = builtins.pathExists (../hosts/darwin + "/${hostName}");
  in
    if nixosHostExists then "x86_64-linux"
    else if darwinHostExists then "aarch64-darwin"
    else "x86_64-linux"; # Default to x86_64-linux

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
          system = getSystemForHost hostName;
        in {
          name = configName;
          value = let
            # Extend both nixpkgs lib and home-manager lib
            extendedLib = inputs.nixpkgs.lib.extend (self: super: {
              custom = import ../lib/default.nix {inherit (inputs.nixpkgs) lib;};
              hm = inputs.home-manager.lib.hm;
            });
          in inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = inputs.nixpkgs.legacyPackages.${system};
            extraSpecialArgs = {
              inherit inputs;
              inherit self;
              lib = extendedLib;
              # Add common special args that home configs might need
              hostSpec = {
                hostName = hostName;
                username = user;
                handle = user;
                # Default values that can be overridden
                isMinimal = false;
                disableSops = true; # Disable sops for standalone home configs
                system = {
                  stateVersion = "24.05";
                };
                home = "/home/${user}";
                isDarwin = system == "aarch64-darwin" || system == "x86_64-darwin";
                hostPlatform = system;
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
                };
              };
              desktops = {};
              nix-secrets = inputs.nix-secrets;
              nur-ryan4yin = inputs.nur-ryan4yin;
            };
            modules = [
              # Pass lib to modules
              {
                _module.args.lib = extendedLib;
              }
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

  # Also keep placeholders for backward compatibility with genUser
  homeConfigPlaceholders = builtins.listToAttrs (
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
  # Use home-manager's flake module to define homeConfigurations
  flake.homeConfigurations = homeConfigurations;

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
