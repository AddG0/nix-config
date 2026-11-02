{
  config,
  lib,
  ...
}:
lib.mkIf config.languages.tailwind.enable {
  plugins.lsp.servers.tailwindcss.enable = true;
}
