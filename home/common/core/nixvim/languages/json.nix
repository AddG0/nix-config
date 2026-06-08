{
  # jsonls auto-wires its `schemas` to SchemaStore.nvim (enabled in ../lsp.nix).
  programs.nixvim.plugins.lsp.servers.jsonls.enable = true;
}
