{
  config,
  lib,
  ...
}:
lib.mkIf config.languages.proto.enable {
  plugins.lsp.servers.protols.enable = true;
  plugins.conform-nvim.settings.formatters_by_ft.proto = ["buf"];
}
