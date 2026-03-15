{inputs, ...}: {
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

  home.shellAliases = {
    vim = "nvim";
    v = "nvim";
    vi = "nvim";
  };
}
