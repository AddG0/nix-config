{pkgs, ...}: {
  # jsonls auto-wires its `schemas` to SchemaStore.nvim (enabled in ../lsp.nix).
  plugins.lsp.servers.jsonls.enable = true;

  # jq reindents pure JSON; jsonc (tsconfig etc.) is a separate ft, untouched.
  plugins.conform-nvim.settings.formatters_by_ft.json = ["jq"];
  extraPackages = [pkgs.jq];
}
