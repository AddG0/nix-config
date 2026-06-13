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
    # Over SSH (no wl-copy/xclip), nvim falls back to the OSC 52 provider. Its
    # paste handler *reads* the terminal clipboard via an escape sequence, which
    # makes Ghostty prompt/flash on every `+` register access. Keep OSC 52 for
    # copy (yanks still reach the local clipboard) but serve paste from nvim's
    # own unnamed register, so nothing ever queries the terminal.
    extraConfigLua = ''
      local osc52 = require("vim.ui.clipboard.osc52")
      local function paste()
        return vim.split(vim.fn.getreg('"'), "\n")
      end
      vim.g.clipboard = {
        name = "OSC 52 (copy-only)",
        copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
        paste = { ["+"] = paste, ["*"] = paste },
      }
    '';
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
    (lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates ["Global/Vim"])
    ++ [
      "kls_database.db" # Created by the kls
    ];

  home.shellAliases = {
    vim = "nvim";
    v = "nvim";
    vi = "nvim";
  };
}
