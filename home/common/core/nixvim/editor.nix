{
  # Navigation + editing plugins. The picker + file explorer come from snacks
  # (configured in ./ui.nix); this module holds the find/explore keymaps and
  # the remaining editor-category plugins.
  programs.nixvim = {
    plugins = {
      # Edit directories like a buffer (complements the snacks tree).
      oil.enable = true;

      flash.enable = true;
      todo-comments.enable = true;
      trouble.enable = true;

      # Treesitter-aware commenting — fixes `gc` comment strings in embedded
      # languages (JSX, Vue templates, etc.). Builtin `gc`/`gcc` still apply.
      ts-comments.enable = true;

      # Session persistence — auto-saves the session per cwd; restore with the
      # <leader>q* maps below.
      persistence.enable = true;

      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };
      };

      # mini.nvim: pairs, surround, ai (text objects). Icons come from
      # web-devicons (ui.nix).
      mini = {
        enable = true;
        modules = {
          pairs = {};
          surround = {};
          ai = {};
        };
      };
    };

    keymaps = [
      {
        # LazyVim-faithful: toggle the explorer. To focus an already-open tree,
        # use <C-h> (it's a left split); <C-l> jumps back to your file.
        mode = "n";
        key = "<leader>e";
        action = "<cmd>lua Snacks.explorer()<cr>";
        options.desc = "Explorer (toggle)";
      }
      {
        mode = "n";
        key = "-";
        action = "<cmd>Oil<cr>";
        options.desc = "Open parent directory";
      }
      # Terminal (snacks). Same key toggles from normal and terminal mode.
      {
        mode = ["n" "t"];
        key = "<C-\\>";
        action = "<cmd>lua Snacks.terminal()<cr>";
        options.desc = "Toggle terminal";
      }
      # Leave terminal-insert mode for normal mode (LazyVim default). Double-esc
      # so a single <esc> still reaches the program running in the terminal.
      {
        mode = "t";
        key = "<esc><esc>";
        action = "<C-\\><C-n>";
        options.desc = "Enter normal mode";
      }
      # Scratch buffers (snacks) — LazyVim defaults. Toggle a per-cwd scratch
      # pad, or pick from previously-created ones.
      {
        mode = "n";
        key = "<leader>.";
        action.__raw = "function() Snacks.scratch() end";
        options.desc = "Toggle scratch buffer";
      }
      {
        mode = "n";
        key = "<leader>S";
        action.__raw = "function() Snacks.scratch.select() end";
        options.desc = "Select scratch buffer";
      }
      # ── snacks pickers ──
      {
        mode = "n";
        key = "<leader><space>";
        action = "<cmd>lua Snacks.picker.files()<cr>";
        options.desc = "Find files";
      }
      {
        mode = "n";
        key = "<leader>ff";
        action = "<cmd>lua Snacks.picker.files()<cr>";
        options.desc = "Find files";
      }
      {
        mode = "n";
        key = "<leader>fr";
        action = "<cmd>lua Snacks.picker.recent()<cr>";
        options.desc = "Recent files";
      }
      {
        mode = "n";
        key = "<leader>fb";
        action = "<cmd>lua Snacks.picker.buffers()<cr>";
        options.desc = "Buffers";
      }
      {
        mode = "n";
        key = "<leader>/";
        action = "<cmd>lua Snacks.picker.grep()<cr>";
        options.desc = "Grep (root)";
      }
      {
        mode = "n";
        key = "<leader>sg";
        action = "<cmd>lua Snacks.picker.grep()<cr>";
        options.desc = "Grep";
      }
      {
        mode = "n";
        key = "<leader>sk";
        action = "<cmd>lua Snacks.picker.keymaps()<cr>";
        options.desc = "Keymaps";
      }
      {
        mode = "n";
        key = "<leader>,";
        action = "<cmd>lua Snacks.picker.buffers()<cr>";
        options.desc = "Buffers";
      }
      {
        mode = "n";
        key = "<leader>:";
        action = "<cmd>lua Snacks.picker.command_history()<cr>";
        options.desc = "Command history";
      }
      {
        mode = ["n" "x"];
        key = "<leader>sw";
        action = "<cmd>lua Snacks.picker.grep_word()<cr>";
        options.desc = "Grep word under cursor";
      }
      {
        mode = "n";
        key = "<leader>sh";
        action = "<cmd>lua Snacks.picker.help()<cr>";
        options.desc = "Help pages";
      }
      {
        mode = "n";
        key = "<leader>sm";
        action = "<cmd>lua Snacks.picker.marks()<cr>";
        options.desc = "Marks";
      }
      {
        mode = "n";
        key = "<leader>sd";
        action = "<cmd>lua Snacks.picker.diagnostics()<cr>";
        options.desc = "Diagnostics";
      }
      {
        mode = "n";
        key = "<leader>ss";
        action = "<cmd>lua Snacks.picker.lsp_symbols()<cr>";
        options.desc = "LSP symbols";
      }
      {
        mode = "n";
        key = "<leader>sR";
        action = "<cmd>lua Snacks.picker.resume()<cr>";
        options.desc = "Resume picker";
      }
      {
        mode = "n";
        key = "<leader>sb";
        action = "<cmd>lua Snacks.picker.lines()<cr>";
        options.desc = "Buffer lines";
      }
      {
        mode = "n";
        key = "<leader>sC";
        action = "<cmd>lua Snacks.picker.commands()<cr>";
        options.desc = "Commands";
      }
      {
        mode = "n";
        key = "<leader>sr";
        action = "<cmd>lua Snacks.picker.registers()<cr>";
        options.desc = "Registers";
      }
      # ── Diagnostics/quickfix (trouble) ──
      {
        mode = "n";
        key = "<leader>xx";
        action = "<cmd>Trouble diagnostics toggle<cr>";
        options.desc = "Diagnostics (Trouble)";
      }
      {
        mode = "n";
        key = "<leader>xt";
        action = "<cmd>TodoTrouble<cr>";
        options.desc = "Todo (Trouble)";
      }
      # ── Code symbols (trouble) — the right-side outline panel of the current
      # file's symbols (functions/classes/…), plus an LSP references/defs panel.
      {
        mode = "n";
        key = "<leader>cs";
        action = "<cmd>Trouble symbols toggle focus=false<cr>";
        options.desc = "Symbols (Trouble)";
      }
      {
        mode = "n";
        key = "<leader>cS";
        action = "<cmd>Trouble lsp toggle focus=false win.position=right<cr>";
        options.desc = "LSP references/definitions/... (Trouble)";
      }

      # flash.nvim motions (LazyVim defaults). nixvim enables the plugin but
      # doesn't bind its keys, so define them here. `s` overrides vim's
      # substitute (use `cl` for that).
      {
        mode = ["n" "x" "o"];
        key = "s";
        action.__raw = "function() require('flash').jump() end";
        options.desc = "Flash";
      }
      {
        mode = ["n" "x" "o"];
        key = "S";
        action.__raw = "function() require('flash').treesitter() end";
        options.desc = "Flash Treesitter";
      }
      {
        mode = "o";
        key = "r";
        action.__raw = "function() require('flash').remote() end";
        options.desc = "Remote Flash";
      }
      {
        mode = ["o" "x"];
        key = "R";
        action.__raw = "function() require('flash').treesitter_search() end";
        options.desc = "Treesitter Search";
      }

      # ── Sessions (persistence.nvim) ──
      {
        mode = "n";
        key = "<leader>qs";
        action.__raw = "function() require('persistence').load() end";
        options.desc = "Restore session";
      }
      {
        mode = "n";
        key = "<leader>ql";
        action.__raw = "function() require('persistence').load({ last = true }) end";
        options.desc = "Restore last session";
      }
      {
        mode = "n";
        key = "<leader>qd";
        action.__raw = "function() require('persistence').stop() end";
        options.desc = "Don't save current session";
      }
    ];
  };
}
