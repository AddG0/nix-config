{
  pkgs,
  inputs,
  ...
}: let
  nix-search = pkgs.writeShellApplication {
    name = "ns";
    runtimeInputs = with pkgs; [
      nix-search-tv # Required by nixpkgs.sh
      fzf # Required by nixpkgs.sh
      gawk # Required by nixpkgs.sh
    ];
    text = builtins.readFile ./nixpkgs.sh;
  };
in {
  imports = [
    inputs.nix-index-database.homeModules.nix-index
  ];

  programs.nix-index.enable = true;

  home.packages = with pkgs; [
    nix-search # Better nix search
    fh # The official nix flake hub
    nix-melt # A TUI flake.lock viewer
    nix-init # generate nix derivation from url
    hydra-check # check hydra(nix's build farm) for the build status of a package
    nix-output-monitor # it provides the command `nom` works just like `nix with more details log output
    nix-tree # nix package tree viewer
    nix-search-tv # nix search tool with TUI
    alejandra # nix formatter
  ];

  home.shellAliases = {
    nixpkgs-fmt = "alejandra";
  };
}
