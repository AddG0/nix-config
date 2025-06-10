# Development shell module
{ inputs, ... }:

{
  perSystem = { pkgs, system, ... }: {
    # Development shells
    devShells = import ../outputs/devshell.nix { 
      self = inputs.self; 
      nixpkgs = inputs.nixpkgs; 
      inherit inputs; 
    } system;

    # Pre-commit hooks for development
    checks = import ../checks { 
      inherit inputs system pkgs; 
    };

    # Code formatter
    formatter = pkgs.alejandra;
  };
} 