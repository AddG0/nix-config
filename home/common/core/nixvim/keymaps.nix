{
  # LazyVim-style core keymaps. Plugin-specific maps live with their plugins.
  keymaps = [
    # ── Motion ── (LazyVim default: move by display line when no count, so
    # j/k navigate wrapped lines naturally — handy in markdown/prose.)
    {
      mode = ["n" "x"];
      key = "j";
      action = "v:count == 0 ? 'gj' : 'j'";
      options = {
        desc = "Down";
        expr = true;
        silent = true;
      };
    }
    {
      mode = ["n" "x"];
      key = "k";
      action = "v:count == 0 ? 'gk' : 'k'";
      options = {
        desc = "Up";
        expr = true;
        silent = true;
      };
    }
    {
      mode = ["n" "x"];
      key = "<Down>";
      action = "v:count == 0 ? 'gj' : 'j'";
      options = {
        desc = "Down";
        expr = true;
        silent = true;
      };
    }
    {
      mode = ["n" "x"];
      key = "<Up>";
      action = "v:count == 0 ? 'gk' : 'k'";
      options = {
        desc = "Up";
        expr = true;
        silent = true;
      };
    }

    # ── Window navigation (vim-tmux-navigator) ──
    # Falls back to a plain window move when there's no tmux pane that way.
    {
      mode = "n";
      key = "<C-h>";
      action = "<cmd>TmuxNavigateLeft<cr>";
      options.desc = "Go to left window/pane";
      options.silent = true;
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<cmd>TmuxNavigateDown<cr>";
      options.desc = "Go to lower window/pane";
      options.silent = true;
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<cmd>TmuxNavigateUp<cr>";
      options.desc = "Go to upper window/pane";
      options.silent = true;
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<cmd>TmuxNavigateRight<cr>";
      options.desc = "Go to right window/pane";
      options.silent = true;
    }

    # ── Window resize ──
    {
      mode = "n";
      key = "<C-Up>";
      action = "<cmd>resize +2<cr>";
      options.desc = "Increase window height";
    }
    {
      mode = "n";
      key = "<C-Down>";
      action = "<cmd>resize -2<cr>";
      options.desc = "Decrease window height";
    }
    {
      mode = "n";
      key = "<C-Left>";
      action = "<cmd>vertical resize -2<cr>";
      options.desc = "Decrease window width";
    }
    {
      mode = "n";
      key = "<C-Right>";
      action = "<cmd>vertical resize +2<cr>";
      options.desc = "Increase window width";
    }

    # ── Buffers ──
    {
      mode = "n";
      key = "<S-h>";
      action = "<cmd>bprevious<cr>";
      options.desc = "Prev buffer";
    }
    {
      mode = "n";
      key = "<S-l>";
      action = "<cmd>bnext<cr>";
      options.desc = "Next buffer";
    }
    {
      mode = "n";
      key = "<leader>bd";
      action = "<cmd>bdelete<cr>";
      options.desc = "Delete buffer";
    }

    # ── Move lines (Alt+j/k) ──
    {
      mode = "n";
      key = "<A-j>";
      action = "<cmd>m .+1<cr>==";
      options.desc = "Move line down";
    }
    {
      mode = "n";
      key = "<A-k>";
      action = "<cmd>m .-2<cr>==";
      options.desc = "Move line up";
    }
    {
      mode = "v";
      key = "<A-j>";
      action = ":m '>+1<cr>gv=gv";
      options.desc = "Move selection down";
    }
    {
      mode = "v";
      key = "<A-k>";
      action = ":m '<-2<cr>gv=gv";
      options.desc = "Move selection up";
    }

    # ── Editing quality-of-life ──
    {
      mode = "n";
      key = "<esc>";
      action = "<cmd>nohlsearch<cr><esc>";
      options.desc = "Clear search highlight";
    }
    {
      mode = ["n" "i" "v"];
      key = "<C-s>";
      action = "<cmd>w<cr><esc>";
      options.desc = "Save file";
    }
    {
      mode = "n";
      key = "<leader>qq";
      action = "<cmd>qa<cr>";
      options.desc = "Quit all";
    }
    {
      mode = "n";
      key = "n";
      action = "nzzzv";
      options.desc = "Next search result (centered)";
    }
    {
      mode = "n";
      key = "N";
      action = "Nzzzv";
      options.desc = "Prev search result (centered)";
    }
    {
      mode = "v";
      key = "<";
      action = "<gv";
    }
    {
      mode = "v";
      key = ">";
      action = ">gv";
    }

    # ── Buffers (extra) ──
    {
      mode = "n";
      key = "[b";
      action = "<cmd>bprevious<cr>";
      options.desc = "Prev buffer";
    }
    {
      mode = "n";
      key = "]b";
      action = "<cmd>bnext<cr>";
      options.desc = "Next buffer";
    }
    {
      mode = "n";
      key = "<leader>bb";
      action = "<cmd>e #<cr>";
      options.desc = "Switch to other buffer";
    }
    {
      mode = "n";
      key = "<leader>bo";
      action.__raw = "function() Snacks.bufdelete.other() end";
      options.desc = "Delete other buffers";
    }
    {
      mode = "n";
      key = "<leader>bD";
      action = "<cmd>:bd<cr>";
      options.desc = "Delete buffer and window";
    }

    # ── Diagnostics navigation (vim.diagnostic.jump, nvim 0.11+) ──
    {
      mode = "n";
      key = "<leader>cd";
      action.__raw = "function() vim.diagnostic.open_float() end";
      options.desc = "Line diagnostics";
    }
    {
      mode = "n";
      key = "]d";
      action.__raw = "function() vim.diagnostic.jump({ count = 1, float = true }) end";
      options.desc = "Next diagnostic";
    }
    {
      mode = "n";
      key = "[d";
      action.__raw = "function() vim.diagnostic.jump({ count = -1, float = true }) end";
      options.desc = "Prev diagnostic";
    }
    {
      mode = "n";
      key = "]e";
      action.__raw = "function() vim.diagnostic.jump({ count = 1, float = true, severity = vim.diagnostic.severity.ERROR }) end";
      options.desc = "Next error";
    }
    {
      mode = "n";
      key = "[e";
      action.__raw = "function() vim.diagnostic.jump({ count = -1, float = true, severity = vim.diagnostic.severity.ERROR }) end";
      options.desc = "Prev error";
    }
    {
      mode = "n";
      key = "]w";
      action.__raw = "function() vim.diagnostic.jump({ count = 1, float = true, severity = vim.diagnostic.severity.WARN }) end";
      options.desc = "Next warning";
    }
    {
      mode = "n";
      key = "[w";
      action.__raw = "function() vim.diagnostic.jump({ count = -1, float = true, severity = vim.diagnostic.severity.WARN }) end";
      options.desc = "Prev warning";
    }

    # ── Quickfix / location list ──
    {
      mode = "n";
      key = "]q";
      action = "<cmd>cnext<cr>";
      options.desc = "Next quickfix";
    }
    {
      mode = "n";
      key = "[q";
      action = "<cmd>cprev<cr>";
      options.desc = "Prev quickfix";
    }
    {
      mode = "n";
      key = "<leader>xq";
      action = "<cmd>Trouble qflist toggle<cr>";
      options.desc = "Quickfix list (Trouble)";
    }
    {
      mode = "n";
      key = "<leader>xl";
      action = "<cmd>Trouble loclist toggle<cr>";
      options.desc = "Location list (Trouble)";
    }

    # ── Windows ──
    # Terminal-aware splits: a plain split of a terminal window would show the
    # same buffer (one pty) in both panes, so keystrokes mirror. When the
    # current buffer is a terminal, spawn a fresh independent terminal in the
    # new pane instead; file buffers split as normal.
    {
      mode = "n";
      key = "<leader>-";
      action.__raw = ''
        function()
          local term = vim.bo.buftype == "terminal"
          vim.cmd("split")
          if term then
            vim.cmd("terminal")
            vim.cmd("startinsert")
          end
        end
      '';
      options.desc = "Split window below";
    }
    {
      mode = "n";
      key = "<leader>|";
      action.__raw = ''
        function()
          local term = vim.bo.buftype == "terminal"
          vim.cmd("vsplit")
          if term then
            vim.cmd("terminal")
            vim.cmd("startinsert")
          end
        end
      '';
      options.desc = "Split window right";
    }
    {
      mode = "n";
      key = "<leader>wd";
      action = "<C-w>c";
      options.desc = "Delete window";
    }
    {
      mode = "n";
      key = "<leader>wm";
      action.__raw = "function() Snacks.toggle.zoom():toggle() end";
      options.desc = "Maximize window (zoom)";
    }

    # ── Tabs ──
    {
      mode = "n";
      key = "<leader><tab><tab>";
      action = "<cmd>tabnew<cr>";
      options.desc = "New tab";
    }
    {
      mode = "n";
      key = "<leader><tab>]";
      action = "<cmd>tabnext<cr>";
      options.desc = "Next tab";
    }
    {
      mode = "n";
      key = "<leader><tab>[";
      action = "<cmd>tabprevious<cr>";
      options.desc = "Previous tab";
    }
    {
      mode = "n";
      key = "<leader><tab>d";
      action = "<cmd>tabclose<cr>";
      options.desc = "Close tab";
    }
    {
      mode = "n";
      key = "<leader><tab>o";
      action = "<cmd>tabonly<cr>";
      options.desc = "Close other tabs";
    }
    {
      mode = "n";
      key = "<leader><tab>f";
      action = "<cmd>tabfirst<cr>";
      options.desc = "First tab";
    }
    {
      mode = "n";
      key = "<leader><tab>l";
      action = "<cmd>tablast<cr>";
      options.desc = "Last tab";
    }

    # ── Buffers / misc ──
    {
      mode = "n";
      key = "<leader>`";
      action = "<cmd>e #<cr>";
      options.desc = "Switch to other buffer";
    }
    {
      mode = "n";
      key = "<leader>K";
      action = "<cmd>norm! K<cr>";
      options.desc = "Keywordprg (help under cursor)";
    }

    # ── UI toggles (Snacks.toggle) ──
    {
      mode = "n";
      key = "<leader>uw";
      action.__raw = ''function() Snacks.toggle.option("wrap", { name = "Wrap" }):toggle() end'';
      options.desc = "Toggle wrap";
    }
    {
      mode = "n";
      key = "<leader>us";
      action.__raw = ''function() Snacks.toggle.option("spell", { name = "Spelling" }):toggle() end'';
      options.desc = "Toggle spelling";
    }
    {
      mode = "n";
      key = "<leader>uL";
      action.__raw = ''function() Snacks.toggle.option("relativenumber", { name = "Relative Number" }):toggle() end'';
      options.desc = "Toggle relative number";
    }
    {
      mode = "n";
      key = "<leader>ul";
      action.__raw = "function() Snacks.toggle.line_number():toggle() end";
      options.desc = "Toggle line numbers";
    }
    {
      mode = "n";
      key = "<leader>ud";
      action.__raw = "function() Snacks.toggle.diagnostics():toggle() end";
      options.desc = "Toggle diagnostics";
    }
    {
      mode = "n";
      key = "<leader>uc";
      action.__raw = ''function() Snacks.toggle.option("conceallevel", { off = 0, on = 2, name = "Conceal Level" }):toggle() end'';
      options.desc = "Toggle conceal";
    }
    {
      mode = "n";
      key = "<leader>uh";
      action.__raw = "function() Snacks.toggle.inlay_hints():toggle() end";
      options.desc = "Toggle inlay hints";
    }
    {
      mode = "n";
      key = "<leader>uT";
      action.__raw = "function() Snacks.toggle.treesitter():toggle() end";
      options.desc = "Toggle treesitter";
    }
    {
      mode = "n";
      key = "<leader>ug";
      action.__raw = "function() Snacks.toggle.indent():toggle() end";
      options.desc = "Toggle indent guides";
    }
    {
      mode = "n";
      key = "<leader>un";
      action.__raw = "function() Snacks.notifier.hide() end";
      options.desc = "Dismiss notifications";
    }
    {
      mode = "n";
      key = "<leader>uz";
      action.__raw = "function() Snacks.toggle.zen():toggle() end";
      options.desc = "Toggle zen mode";
    }
    {
      mode = "n";
      key = "<leader>ui";
      action.__raw = "vim.show_pos";
      options.desc = "Inspect position";
    }
    {
      mode = "n";
      key = "<leader>uI";
      action.__raw = "function() vim.treesitter.inspect_tree() vim.api.nvim_input('I') end";
      options.desc = "Inspect treesitter tree";
    }

    # ── Misc ──
    {
      mode = "n";
      key = "<leader>ur";
      action = "<cmd>nohlsearch<bar>diffupdate<cr>";
      options.desc = "Redraw / clear hlsearch";
    }
    {
      mode = "n";
      key = "<leader>fn";
      action = "<cmd>enew<cr>";
      options.desc = "New file";
    }
  ];
}
