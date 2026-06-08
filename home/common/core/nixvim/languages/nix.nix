{
  pkgs,
  osConfig,
  self,
  ...
}: let
  # nixd evaluates these strings itself (lazily) to learn your option set, which
  # is what makes hovering an option show its type + declared description (the
  # module comments). They point at THIS flake via `self` — a /nix/store snapshot
  # of the repo — rather than the editor's workspace dir. The upshot: option and
  # package hover works in EVERY nix repo you open (nix-secrets, package flakes,
  # a scratch dir, …), always resolved against your real config's full option
  # universe, not just files that live inside this repo. Trade-off: it reflects
  # the last rebuild, not uncommitted edits — fine for docs, and it avoids the
  # slow "dirty tree" re-copy you'd get pointing at the live working tree.
  flake = ''builtins.getFlake "${self}"'';
  host = osConfig.networking.hostName;
in {
  programs.nixvim = {
    plugins.lsp.servers.nixd = {
      enable = true;
      settings.nixd = {
        # Package + lib completion/hover, from this flake's own nixpkgs input.
        nixpkgs.expr = "import (${flake}).inputs.nixpkgs { }";
        formatting.command = ["alejandra"];
        options = {
          nixos.expr = "(${flake}).nixosConfigurations.${host}.options";
          # Integrated home-manager (rebuilt via nixos-rebuild) exposes its
          # options under the nixos module — pull the user submodule's set.
          "home-manager".expr = "(${flake}).nixosConfigurations.${host}.options.home-manager.users.type.getSubOptions []";
        };
      };
    };
    plugins.conform-nvim.settings.formatters_by_ft.nix = ["alejandra"];
    extraPackages = [pkgs.alejandra];
  };
}
