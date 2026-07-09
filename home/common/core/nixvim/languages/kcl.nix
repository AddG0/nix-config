{
  pkgs,
  lib,
  ...
}: {
  # Neovim's builtin detection maps `.k` to `kwt` (Kimwitu++), not KCL — force it.
  extraConfigLua = ''
    vim.filetype.add({ extension = { k = "kcl" } })
  '';

  # kcl-language-server is in nixvim's `unpackaged` server list, so the package
  # must be supplied explicitly (unlike gopls/protols which nixvim provides).
  #
  # Linux-only: both kcl and kcl-language-server are linux-only in nixpkgs, so the
  # server + formatter are gated here (same as kotlin.nix) — on darwin (e.g. the
  # standalone `nix run .#nvim`) kcl gets filetype detection but no LSP/format.
  plugins.lsp.servers.kcl = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    enable = true;
    package = pkgs.kcl-language-server;
  };

  # conform's `kcl` formatter runs `kcl fmt`; autoInstall resolves it to pkgs.kcl.
  plugins.conform-nvim.settings.formatters_by_ft.kcl =
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux ["kcl"];
}
