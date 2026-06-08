{pkgs, ...}: {
  programs.nixvim = {
    plugins.lsp.servers.lua_ls.enable = true;
    plugins.conform-nvim.settings.formatters_by_ft.lua = ["stylua"];
    extraPackages = [pkgs.stylua];
  };
}
