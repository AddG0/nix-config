# checks/flake-module.nix - Quality assurance and validation checks
{...}: {
  imports = [
    ./formatting.nix # Code formatting validation (treefmt)
    ./pre-commit-checks.nix # Pre-commit hooks and legacy checks
    ./packages.nix # Package build validation
    ./tests.nix # Every tests/<kind>.nix under modules/, home/, lib/ and checks/, named <kind>:<area>[:<sub>]
    ./devshells.nix # Development shell validation
    ./nvim-darwin.nix # Eval-guard: standalone nvim must build on aarch64-darwin
    ./configurations.nix # Eval-guards: home/darwin configs, base extension, stock-lib importers
  ];
}
