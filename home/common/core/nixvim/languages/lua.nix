{
  plugins.lsp.servers.lua_ls.enable = true;
  # lua_ls emits no CodeLens unless explicitly opted in.
  plugins.lsp.servers.lua_ls.settings.Lua.codeLens.enable = true;
  plugins.conform-nvim.settings.formatters_by_ft.lua = ["stylua"];
}
