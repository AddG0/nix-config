{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./ui.nix
    ./editor.nix
    ./navigation.nix
    ./lsp.nix
    ./git.nix
  ];

  programs.nixvim = {
    enable = true;
    clipboard.register = "unnamedplus";
    globals.mapleader = " ";
  };

  programs.git.ignores = lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates ["Global/Vim"];

  home.shellAliases = {
    vim = "nvim";
    v = "nvim";
    vi = "nvim";
  };
}
