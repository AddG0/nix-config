# checks/flake-module.nix - Quality assurance and validation checks
{...}: {
  imports = [
    # Code quality and formatting
    ./formatting.nix # Code formatting validation (treefmt)
    ./pre-commit-checks.nix # Pre-commit hooks and legacy checks
    
    # Build and configuration validation  
    ./packages.nix # Package build validation
    ./machines.nix # NixOS/Darwin configuration validation
    ./devshells.nix # Development shell validation
    ./home-manager.nix # Home-manager configuration validation
  ];
}
