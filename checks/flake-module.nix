# checks/flake-module.nix - Quality assurance and validation checks
{...}: {
  imports = [
    ./formatting.nix # Code formatting validation (treefmt)
    ./pre-commit-checks.nix # Pre-commit hooks and legacy checks
    ./packages.nix # Package build validation
    ./module-tests.nix # Colocated module tests (modules/**/tests.nix)
    ./devshells.nix # Development shell validation
    ./nvim-darwin.nix # Eval-guard: standalone nvim must build on aarch64-darwin
  ];
}
