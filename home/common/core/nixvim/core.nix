{
  # Core editor settings shared by the home-manager module (default.nix) and the
  # standalone build (packages.nvim). Prefix-less nixvim options so both the
  # `programs.nixvim` submodule and `evalNixvim` can import it directly.

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
}
