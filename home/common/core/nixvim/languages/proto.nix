{pkgs, ...}: {
  plugins.lsp.servers.protols.enable = true;
  plugins.conform-nvim.settings.formatters_by_ft.proto = ["buf"];
  extraPackages = [pkgs.buf]; # proto format/lint (≠ protols)
}
