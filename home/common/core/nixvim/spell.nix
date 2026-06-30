{pkgs, ...}: {
  extraPackages = [pkgs.cspell];

  # cspell on every real buffer. nvim-lint resolves linters by exact filetype
  # (no "*"/"_" wildcard), so run it directly instead of via lintersByFt.
  # Project words → cspell.json at the repo root.
  autoCmd = [
    {
      event = ["BufReadPost" "BufWritePost" "InsertLeave"];
      callback.__raw = ''
        function()
          if vim.bo.buftype == "" then
            require("lint").try_lint("cspell")
          end
        end
      '';
    }
  ];
}
