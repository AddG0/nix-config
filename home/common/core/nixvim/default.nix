{
  inputs,
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

  # The GitHub Global/Vim template ships an over-broad swap-file glob
  # `[._]s[a-rt-v][a-z]` that also matches `.sdd` (our spec-driven-development
  # folder), silently untracking the whole directory. The other swap patterns
  # in the template (`[._]*.s[a-v][a-z]`, `[._]sw[a-p]`, etc.) already cover
  # real vim swap files, so filtering this one out loses no coverage.
  programs.git.ignores =
    lib.filter (line: line != "[._]s[a-rt-v][a-z]")
    (lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates ["Global/Vim"]);

  home.shellAliases = {
    vim = "nvim";
    v = "nvim";
    vi = "nvim";
  };
}
