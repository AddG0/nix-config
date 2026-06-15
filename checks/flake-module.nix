# checks/flake-module.nix - Quality assurance and validation checks
{...}: {
  imports = [
    ./formatting.nix # Code formatting validation (treefmt)
    ./pre-commit-checks.nix # Pre-commit hooks and legacy checks
    ./packages.nix # Package build validation
    ./devshells.nix # Development shell validation
    ./nvim-darwin.nix # Eval-guard: standalone nvim must build on aarch64-darwin
  ];
}
