# home/flake-module.nix - Home-manager configuration discovery and exports
{
  self,
  inputs,
  lib,
  ...
}: let
  # Scan home/primary/ for host .nix files (each file = one home-manager config)
  hostFiles = builtins.filter (
    name: lib.hasSuffix ".nix" name && name != "default.nix"
  ) (builtins.attrNames (builtins.readDir ./primary));

  mkHostName = file: lib.removeSuffix ".nix" file;

  # Dummy hostSpec for standalone `home-manager switch` — real values come from NixOS/Darwin host configs
  mkHostSpec = hostName: {
    inherit hostName;
    username = "primary";
    handle = "primary";
    home = "/home/primary";
    isMinimal = false;
    hostType = "desktop";
    isDarwin = false;
    disableSops = true;
    hostPlatform = "x86_64-linux";
    system.stateVersion = "24.05";
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
      ssh.extraConfig = "";
      hostsAddr = {};
    };
  };

  homeConfigurations = builtins.listToAttrs (map (file: let
      hostName = mkHostName file;
    in {
      name = hostName;
      value = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          inherit inputs self lib;
          hostSpec = mkHostSpec hostName;
          desktops = {};
        };
        modules = [
          {_module.args.lib = lib;}
          ./primary/${file}
        ];
      };
    })
    hostFiles);
in {
  flake = {
    inherit homeConfigurations;
  };
}
