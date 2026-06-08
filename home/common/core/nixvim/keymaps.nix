{
  # LazyVim-style core keymaps. Plugin-specific maps live with their plugins.
  programs.nixvim.keymaps = [
    # ── Window navigation ──
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
      options.desc = "Go to left window";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
      options.desc = "Go to lower window";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
      options.desc = "Go to upper window";
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
      options.desc = "Go to right window";
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
    {
      mode = "n";
      key = "<leader>-";
      action = "<C-w>s";
      options.desc = "Split window below";
    }
    {
      mode = "n";
      key = "<leader>|";
      action = "<C-w>v";
      options.desc = "Split window right";
    }
    {
      mode = "n";
      key = "<leader>wd";
      action = "<C-w>c";
      options.desc = "Delete window";
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
