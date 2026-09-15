{pkgs, ...}: let
  tsCrystal = pkgs.tree-sitter-grammars.tree-sitter-crystal;

  # Not an nvim-treesitter language; its nvim queries sit in queries/nvim/, a
  # level deeper than grammarToPlugin looks, so re-lay them out by hand.
  crystalGrammar = pkgs.vimUtils.toVimPlugin (
    pkgs.runCommandLocal "nvim-treesitter-grammar-crystal" {} ''
      mkdir -p $out/parser $out/queries/crystal
      ln -s ${tsCrystal}/parser $out/parser/crystal.so
      ln -s ${tsCrystal}/queries/nvim/*.scm $out/queries/crystal/
    ''
  );
in {
  # vim-crystal for indent + commentstring: no indents.scm, no ts-comments entry.
  extraPlugins = [crystalGrammar pkgs.vimPlugins.vim-crystal];
  globals.crystal_define_mappings = 0; # its ftplugin rebinds gd over the LSP map

  # crystalline execs `crystal env` at startup and dies without it.
  extraPackages = [pkgs.crystal pkgs.pkg-config];

  plugins.lsp.servers.crystalline.enable = true;
  plugins.conform-nvim.settings.formatters_by_ft.crystal = ["crystal"];

  plugins.lint = {
    lintersByFt.crystal = ["ameba"];
    linters.ameba.cmd = "ameba"; # nvim-lint defaults to shards' vendored bin/ameba
  };
}
