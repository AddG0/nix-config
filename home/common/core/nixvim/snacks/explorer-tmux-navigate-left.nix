# <C-h> in the explorer just returns focus to the main buffer instead of
# reaching the tmux pane on the left: the list window snacks actually
# focuses is a float layered over the sidebar split (non-root layout boxes
# get relative = "win", position = "float" in snacks/win.lua), and Neovim's
# wincmd doesn't traverse floats the way vim-tmux-navigator's
# TmuxAwareNavigate assumes when deciding whether to forward to tmux.
#
# DELETE THIS FILE once vim-tmux-navigator (or snacks) navigates out of a
# floating picker window correctly.
_: {
  plugins.snacks.settings.picker.sources.explorer = {
    actions.tmux_navigate_left.__raw = ''
      function()
        if vim.env.TMUX then
          vim.fn.system("tmux select-pane -t " .. vim.env.TMUX_PANE .. " -L")
        else
          vim.cmd("wincmd h")
        end
      end
    '';
    win.list.keys."<C-h>" = "tmux_navigate_left";
  };
}
