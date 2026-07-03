{pkgs, ...}: {
  # Tiltfile is Starlark, but nvim ships no detection for it. Map the filename to
  # the `tiltfile` ft (what tilt_ls expects), alias the starlark TS parser to it
  # for highlighting, and start treesitter on open (nixvim's highlight autocmd
  # only fires for filetypes it knows a parser for).
  extraConfigLua = ''
    vim.filetype.add({
      extension = { tilt = "tiltfile" },
      filename = { Tiltfile = "tiltfile" },
      pattern = {
        ["Tiltfile%..*"] = "tiltfile",
        [".*%.[tT]iltfile"] = "tiltfile",
      },
    })
    vim.treesitter.language.register("starlark", "tiltfile")
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "tiltfile",
      callback = function(ev) pcall(vim.treesitter.start, ev.buf, "starlark") end,
    })
  '';

  # Tilt's own LSP (`tilt lsp start`) — Tiltfile-aware completion for builtins.
  plugins.lsp.servers.tilt_ls = {
    enable = true;
    package = pkgs.tilt;
  };
}
