{
  inputs,
  lib,
  ...
}: {
  imports =
    [inputs.nixvim.homeModules.nixvim]
    ++ (lib.custom.scanPaths ./.);

  programs.nixvim = {
    enable = true;
    # Yank/delete/paste through the system clipboard (the `+` register) by
    # default, so copy/paste works between nvim and other apps without `"+`.
    clipboard.register = "unnamedplus";
    # Leader key = space (prefix for all `<leader>…` maps). Set here, before
    # the keymap modules load, since mapleader is read when a mapping is defined.
    globals.mapleader = " ";
  };

  # The GitHub Global/Vim gitignore template ships an over-broad swap-file
  # glob `[._]s[a-rt-v][a-z]` that also matches `.sdd` (our spec-driven-
  # development folder), silently untracking the whole directory. The other
  # swap patterns in the template already cover real vim swap files, so
  # filtering this one out loses no coverage.
  programs.git.ignores =
    lib.filter (line: line != "[._]s[a-rt-v][a-z]")
    (lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates ["Global/Vim"]);

  home.shellAliases = {
    vim = "nvim";
    v = "nvim";
    vi = "nvim";
  };
}
