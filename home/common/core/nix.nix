# Nix related packages
{pkgs, ...}: let
  ns = pkgs.writeShellScriptBin "ns" (builtins.readFile ./cli/scripts/nixpkgs.sh);
in {
  home.packages = with pkgs; [
    fh # The official nix flake hub
    nix-output-monitor # it provides the command `nom` works just like `nix with more details log output
    hydra-check # check hydra(nix's build farm) for the build status of a package
    nix-index # A small utility to index nix store paths
    nix-init # generate nix derivation from url
    nix-melt # A TUI flake.lock viewer
    nixpkgs-fmt # formatter for nixpkgs
    nix-tree # nix package tree viewer
    alejandra # nix formatter
    nixd # nix language server

    # nix search tool with TUI
    nix-search-tv # nix search tool with TUI
  ];

  home.shellAliases = {
    nixpkgs-fmt = "alejandra";
  };
}
