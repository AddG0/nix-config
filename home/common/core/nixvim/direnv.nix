{
  # Exports the project's direnv env into nvim so LSP servers (spawned as nvim children) resolve deps from the dev-env python.
  plugins.direnv = {
    enable = true;
    settings.silent_load = 1; # match programs.direnv.silent
  };

  # A direnv reload rebuilds PATH from DIRENV_DIFF's snapshot, taken before the nixvim
  # wrapper appended its server bins — servers outside the project's devShell go "not
  # executable" mid-session. Current PATH stays first so devShell tools still win;
  # deduped so repeat reloads don't grow it.
  extraConfigLua = ''
    local startup_path = vim.env.PATH
    vim.api.nvim_create_autocmd("User", {
      pattern = "DirenvLoaded",
      desc = "Restore nvim's own PATH entries after a direnv reload",
      callback = function()
        local seen, entries = {}, {}
        for entry in (vim.env.PATH .. ":" .. startup_path):gmatch("[^:]+") do
          if not seen[entry] then
            seen[entry] = true
            entries[#entries + 1] = entry
          end
        end
        vim.env.PATH = table.concat(entries, ":")
      end,
    })
  '';
}
