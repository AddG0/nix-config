# checks/configurations.nix - Eval guards for outputs `nix flake check` doesn't evaluate on its own.
# Each forces a drvPath (builtins.seq, never built), so any system can check every platform's configs.
{
  self,
  inputs,
  lib,
  ...
}: let
  # Downstream flakes extend base; they must get our customPkgs, pkgs.addg, lib.custom and exported options.
  baseExtended = self.nixosConfigurations.base.extendModules {
    modules = [
      ({
        lib,
        pkgs,
        customPkgs,
        ...
      }: {
        assertions = [
          {
            assertion = lib ? custom;
            message = "base extenders must receive lib.custom";
          }
        ];
        environment.systemPackages = [customPkgs.gwq pkgs.addg.gwq];
        programs.wifiman-desktop.enable = true;
      })
      ({config, ...}: {
        home-manager.users.${config.hostSpec.primaryUsername}.imports = [
          ({customPkgs, ...}: {home.packages = [customPkgs.themes.catppuccin.bat];})
        ];
      })
    ];
  };

  # Importers get only a stock nixpkgs lib and no specialArgs.
  stockLibImporter = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.default
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "/dev/null";
          fsType = "ext4";
        };
        system.stateVersion = "26.05";
        hostSpec = {
          primaryUsername = "importer";
          userFullName = "Importer";
          handle = "importer";
          email = {};
          githubEmail = "importer@example.com";
          hostName = "importer";
          domain = "example.com";
          hostPlatform = "x86_64-linux";
        };
      }
    ];
  };
in {
  perSystem = {pkgs, ...}: let
    guard = name: drv: pkgs.runCommand name {forced = builtins.seq drv.drvPath "ok";} "touch $out";
    guards = prefix: f: configs: lib.mapAttrs' (n: c: lib.nameValuePair "${prefix}-${n}-evals" (guard "${prefix}-${n}-evals" (f c))) configs;
  in {
    checks =
      guards "home" (c: c.activationPackage) self.homeConfigurations
      // guards "darwin" (c: c.config.system.build.toplevel) self.darwinConfigurations
      // {
        base-extension-evals = guard "base-extension-evals" baseExtended.config.system.build.toplevel;
        exported-modules-stock-lib-evals = guard "exported-modules-stock-lib-evals" stockLibImporter.config.system.build.toplevel;
      };
  };
}
