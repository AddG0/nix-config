# Shell for bootstrapping flake-enabled nix and other tooling
{
  pkgs ?
  # If pkgs is not defined, instanciate nixpkgs from locked commit
  let
    lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
    nixpkgs = fetchTarball {
      url = "https://github.com/nixos/nixpkgs/archive/${lock.rev}.tar.gz";
      sha256 = lock.narHash;
    };
  in
    import nixpkgs {overlays = [];},
  checks ? {},
  ...
}: {
  default = pkgs.mkShell {
    NIX_CONFIG = "extra-experimental-features = nix-command flakes";

    shellHook = checks.pre-commit-check.shellHook or "";
    buildInputs = checks.pre-commit-check.enabledPackages or [];

    nativeBuildInputs = builtins.attrValues {
      inherit
        (pkgs)
        home-manager
        git
        just
        age
        ssh-to-age
        colmena
        sops
        ;
    };
  };
}
