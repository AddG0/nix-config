# modules/flake-module.nix - Custom NixOS, Darwin, and Home-manager modules
{inputs, lib, ...}: let
  # Get available systems from flake inputs
  supportedSystems = lib.systems.flakeExposed;
  
  # Check if we have any Linux systems (for NixOS modules) 
  hasLinux = builtins.any (system: 
    lib.hasPrefix "x86_64-linux" system || 
    lib.hasPrefix "aarch64-linux" system
  ) supportedSystems;
  
  # Check if we have any Darwin systems (for Darwin modules)
  hasDarwin = builtins.any (system: 
    lib.hasPrefix "x86_64-darwin" system || 
    lib.hasPrefix "aarch64-darwin" system
  ) supportedSystems;
in {
  flake = {
    # NixOS modules - only expose if we have Linux systems
    nixosModules = lib.mkIf hasLinux {
      # Default includes common modules + NixOS-specific modules
      default = {
        imports = [
          ./common
          ./common/nixos
          ./hosts
          ./hosts/nixos
        ];
      };
    };

    # Darwin modules - only expose if we have Darwin systems
    darwinModules = lib.mkIf hasDarwin {
      # Default includes common modules + Darwin-specific modules  
      default = {
        imports = [
          ./common
          ./common/darwin
          ./hosts
          ./hosts/darwin
        ];
      };
    };

    # Home-manager modules - always available (cross-platform)
    homeModules = {
      # Default includes all home modules
      default = {
        imports = [
          ./common
          ./home
        ];
      };
    };
  };
}