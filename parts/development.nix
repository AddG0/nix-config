# parts/development.nix - Development tools, checks, devShells, formatter
{inputs, ...}: {
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    system,
    ...
  }: {
    # Development shells
    devShells =
      import ../outputs/devshell.nix {
        self = inputs.self;
        inherit inputs;
        nixpkgs = inputs.nixpkgs;
      }
      system;

    # Checks
    checks = import ../checks {inherit inputs system pkgs;};

    # Code formatter
    formatter = pkgs.alejandra;
  };
}
