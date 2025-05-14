{
  self,
  nixpkgs,
  inputs,
  ...
}: system: let
  pkgs = nixpkgs.legacyPackages.${system};
in {
  default = pkgs.mkShell {
    packages = with pkgs;
      [
        bashInteractive
        gcc
        alejandra
        deadnix
        statix
        typos
        colmena
        nixos-generators
        nix-update
      ]
      ++ [
        inputs.nixpkgs-update.packages.${system}.nixpkgs-update
      ];
    name = "dots";
    shellHook = ''
      ${self.checks.${system}.pre-commit-check.shellHook}
    '';
  };
}
