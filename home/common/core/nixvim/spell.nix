{pkgs, ...}: {
  # typos-lsp checks every file — it only flags known misspellings, so unlike
  # cspell it stays quiet on identifiers and project names.
  plugins.lsp.servers.typos_lsp.enable = true;

  extraPackages = [pkgs.cspell];

  # cspell is dictionary-based and noisy on code, so scope it to prose. nvim-lint
  # resolves linters by exact filetype (no wildcard), so run it directly.
  # Project words → cspell.json at the repo root.
  autoCmd = [
    {
      event = ["BufReadPost" "BufWritePost" "InsertLeave"];
      callback.__raw = ''
        function()
          local ft = vim.bo.filetype
          if ft == "markdown" or ft == "text" or ft == "gitcommit" then
            require("lint").try_lint("cspell")
          end
        end
      '';
    }
  ];
}
