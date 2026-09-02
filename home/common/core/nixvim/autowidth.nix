# Grow-to-fit width for the two file sidebars: the snacks explorer and
# diffview's file panel. Both ship a fixed width (40 and 35), so nested paths
# and long filenames get truncated.
#
# Grow-only while a sidebar stays open: the explorer's list buffer holds just
# the rows on screen, so recomputing downwards would twitch as you scroll.
# Reopening starts back at the plugin's own width. A width you set by hand wins
# from then on — fitting stops once the pane is no longer the size we left it.
#
# DELETE THIS FILE once both plugins grow a native fit-to-content width.
_: {
  extraConfigLua = ''
    -- shared so the explorer and diffview agree on the cap and on when to yield
    -- to a hand-set width
    function _G.FitSidebar(buf, win, min, max, on_resize)
      local applied = vim.w[win].autowidth
      local current = vim.api.nvim_win_get_width(win)
      if applied and current ~= applied then
        return
      end
      local want = min
      for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        -- measure the entry, not its symlink target: a `result -> /nix/store/…`
        -- row would peg every repo holding a build symlink at `max`
        local entry = line:match("^(.-) %-> ") or line
        want = math.max(want, vim.fn.strdisplaywidth(entry) + 1)
      end
      if math.min(want, max) > current then
        vim.api.nvim_win_set_width(win, math.min(want, max))
        if on_resize then
          on_resize()
        end
        -- read back: the caller's layout may not honour the width exactly, and a
        -- mismatch here would read as a hand-set width on the next call
        vim.w[win].autowidth = vim.api.nvim_win_get_width(win)
      end
    end
  '';

  plugins = {
    snacks.settings.picker.sources.explorer.on_change.__raw = ''
      function(picker)
        local layout = picker.layout
        if not (layout and layout.root and layout.root:win_valid()) then
          return
        end
        -- the root carries the size; resizing the list leaves the input box behind
        _G.FitSidebar(picker.list.win.buf, layout.root.win, 0, 60, function()
          layout:update()
        end)
      end
    '';

    # diffview sizes the panel only in Panel:open(), and the panel is
    # winfixwidth, so a width set here is not overwritten.
    diffview.settings.hooks.view_post_layout.__raw = ''
      function(view)
        local panel = view and view.panel
        -- one attachment per panel: the hook fires again on every layout change
        if not (panel and panel.bufid) or vim.b[panel.bufid].autowidth_attached then
          return
        end
        vim.b[panel.bufid].autowidth_attached = true
        -- the panel renders asynchronously, so fit on each render rather than
        -- guessing when the file list has landed
        vim.api.nvim_buf_attach(panel.bufid, false, {
          on_lines = function()
            if not (panel.winid and vim.api.nvim_win_is_valid(panel.winid)) then
              return true
            end
            vim.schedule(function()
              if vim.api.nvim_win_is_valid(panel.winid) then
                _G.FitSidebar(panel.bufid, panel.winid, 35, 60)
              end
            end)
          end,
        })
      end
    '';
  };
}
