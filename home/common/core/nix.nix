{
  pkgs,
  hostSpec,
  self,
  lib,
  ...
}: {
  home.packages = with pkgs;
    [
      fh # The official nix flake hub
      nix-output-monitor # it provides the command `nom` works just like `nix with more details log output
      hydra-check # check hydra(nix's build farm) for the build status of a package
      nix-index # A small utility to index nix store paths
      nix-init # generate nix derivation from url
      nix-melt # A TUI flake.lock viewer
      nixpkgs-fmt # formatter for nixpkgs
      alejandra # nix formatter
      nixd # nix language server
    ]
    ++ lib.optionals (hostSpec.hostType != "server") [
      nix-tree # nix package tree viewer
      # nix search tool with TUI
      nix-search-tv # nix search tool with TUI
    ];

  home.shellAliases = {
    nixpkgs-fmt = "alejandra";
  };

  nixpkgs = {
    overlays = builtins.attrValues self.overlays;
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };
}
