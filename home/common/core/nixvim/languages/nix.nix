{
  lib,
  self,
  osConfig ? null,
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
in {
  plugins.lsp.servers.nixd = {
    enable = true;
    # nixd defaults to --log=info, which traces every request to stderr; nvim
    # captures that as ERROR and writes it to lsp.log synchronously as you type.
    cmd = ["nixd" "--log=error"];
    # FLAKE-UPDATE: drop once the pinned Neovim gates auto-attach by buffer name
    # (neovim#32074, milestone 0.13). nixd inherits clangd's file://-only URI
    # parser, so diffview:// buffers fail every request with -32602. Declining
    # on_dir is the only pre-attach hook; a detach from LspAttach gets reverted.
    extraOptions.root_dir.__raw = ''
      function(bufnr, on_dir)
        local uri = vim.uri_from_bufnr(bufnr)
        if not vim.startswith(uri, "file://") or uri:find("/%.git/") then return end
        on_dir() -- nil root: vim.lsp.start still resolves root_markers
      end
    '';
    settings.nixd =
      {
        # Package + lib completion/hover, from this flake's own nixpkgs input.
        nixpkgs.expr = "import (${flake}).inputs.nixpkgs { }";
        formatting.command = ["alejandra"];
      }
      # Option/HM hover resolves against a specific host; there's no host in
      # the standalone build (packages.nvim, osConfig == null), so include it
      # only when a host is present — everything else stays identical.
      // lib.optionalAttrs (osConfig != null) {
        options = let
          host = osConfig.networking.hostName;
        in {
          nixos.expr = "(${flake}).nixosConfigurations.${host}.options";
          # Integrated home-manager (rebuilt via nixos-rebuild) exposes its
          # options under the nixos module — pull the user submodule's set.
          "home-manager".expr = "(${flake}).nixosConfigurations.${host}.options.home-manager.users.type.getSubOptions []";
        };
      };
  };
  # conform autoInstall puts alejandra on nvim's PATH, so nixd's formatting.command above finds it too.
  plugins.conform-nvim.settings.formatters_by_ft.nix = ["alejandra"];
}
