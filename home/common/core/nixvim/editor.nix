{
  # Navigation + editing plugins. The picker + file explorer come from snacks
  # (configured in ./ui.nix); this module holds the find/explore keymaps and
  # the remaining editor-category plugins.
  plugins = {
    flash.enable = true;
    todo-comments.enable = true;
    trouble.enable = true;

    # Subtly highlight other usages of the symbol under the cursor (VSCode
    # "occurrence highlight"). LSP-aware: uses the language server's
    # document-highlight provider when attached, else treesitter, else regex.
    illuminate.enable = true;

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

    # Sticky scope (nvim-treesitter-context): pins the enclosing
    # function/class/block at the top of the window while you scroll, so you
    # always see what you're inside. max_lines caps how tall it can get.
    treesitter-context = {
      enable = true;
      settings.max_lines = 3;
    };

    # Syntax-aware text objects: af/if (function), ac/ic (class), aa/ia
    # (parameter), plus ]f/[f ]c/[c ]a/[a movement between them (keymaps
    # below). The plugin refactored away from setup-configured keymaps, so we
    # drive it through its module API; lookahead is set in extraConfigLua.
    treesitter-textobjects.enable = true;

    # Auto-close and auto-rename HTML/JSX/XML tags (treesitter-driven).
    ts-autotag.enable = true;

    # Folding. origami is batteries-included: `enable` alone turns on LSP folds
    # (treesitter fallback), auto-fold of imports + comments on open, fancy
    # foldtext, search-pausing, and smart h/l/$/^ fold keymaps. foldlevel 99
    # (options.nix) keeps everything but those folded regions open on load.
    # Sole override: closeOnlyOnFirstColumn so h/^ fold only at column 0 (default
    # = anywhere in the indent); set false for the snappier behaviour.
    origami = {
      enable = true;
      settings.foldKeymaps.closeOnlyOnFirstColumn = true;
    };

    # Project-wide find & replace with live preview (<leader>sr).
    grug-far.enable = true;

    # mini.nvim: pairs, surround, ai (text objects), hipatterns (inline
    # highlight of #rrggbb colour codes as swatches). Icons come from
    # web-devicons (ui.nix).
    mini = {
      enable = true;
      modules = {
        pairs = {};
        surround = {};
        ai = {};
        hipatterns = {
          highlighters.hex_color.__raw = "require('mini.hipatterns').gen_highlighter.hex_color()";
        };
      };
    };

    # Smart increment/decrement (<C-a>/<C-x>): numbers, dates, booleans,
    # and more, in normal + visual mode (keymaps below). Defaults cover the
    # common augends.
    dial.enable = true;

    # Yank ring: after a paste, <C-p>/<C-n> cycle back through yank history
    # (keymaps below). y/p/P route through yanky to feed the ring.
    yanky.enable = true;
  };

  # treesitter-textobjects refactored away from setup-based config; nixvim no
  # longer calls its setup(), so do it here just to enable lookahead (jump
  # forward to the next textobject when the cursor isn't inside one).
  extraConfigLua = ''
    require('nvim-treesitter-textobjects').setup({ select = { lookahead = true } })
  '';

  keymaps = [
    {
      # LazyVim-faithful: toggle the explorer. To focus an already-open tree,
      # use <C-h> (it's a left split); <C-l> jumps back to your file.
      mode = "n";
      key = "<leader>e";
      action = "<cmd>lua Snacks.explorer()<cr>";
      options.desc = "Explorer (toggle)";
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
    # Add a comment on a new line below/above (LazyVim defaults; complements
    # the builtin gc/gcc + ts-comments above).
    {
      mode = "n";
      key = "gco";
      action = "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>";
      options.desc = "Add comment below";
    }
    {
      mode = "n";
      key = "gcO";
      action = "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>";
      options.desc = "Add comment above";
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
      key = "<leader>s\"";
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

    # ── treesitter-textobjects: select (operator + visual) ──
    # Upgrades mini.ai's af/aa to treesitter function/class/parameter
    # *definitions* (LazyVim behaviour); ic/ac are net-new.
    {
      mode = ["x" "o"];
      key = "af";
      action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@function.outer', 'textobjects') end";
      options.desc = "Function (outer)";
    }
    {
      mode = ["x" "o"];
      key = "if";
      action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@function.inner', 'textobjects') end";
      options.desc = "Function (inner)";
    }
    {
      mode = ["x" "o"];
      key = "ac";
      action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@class.outer', 'textobjects') end";
      options.desc = "Class (outer)";
    }
    {
      mode = ["x" "o"];
      key = "ic";
      action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@class.inner', 'textobjects') end";
      options.desc = "Class (inner)";
    }
    {
      mode = ["x" "o"];
      key = "aa";
      action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@parameter.outer', 'textobjects') end";
      options.desc = "Parameter (outer)";
    }
    {
      mode = ["x" "o"];
      key = "ia";
      action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@parameter.inner', 'textobjects') end";
      options.desc = "Parameter (inner)";
    }

    # ── treesitter-textobjects: movement (normal + visual + operator) ──
    {
      mode = ["n" "x" "o"];
      key = "]f";
      action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_next_start('@function.outer', 'textobjects') end";
      options.desc = "Next function start";
    }
    {
      mode = ["n" "x" "o"];
      key = "[f";
      action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_previous_start('@function.outer', 'textobjects') end";
      options.desc = "Prev function start";
    }
    {
      mode = ["n" "x" "o"];
      key = "]c";
      action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_next_start('@class.outer', 'textobjects') end";
      options.desc = "Next class start";
    }
    {
      mode = ["n" "x" "o"];
      key = "[c";
      action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_previous_start('@class.outer', 'textobjects') end";
      options.desc = "Prev class start";
    }
    {
      mode = ["n" "x" "o"];
      key = "]a";
      action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_next_start('@parameter.inner', 'textobjects') end";
      options.desc = "Next parameter";
    }
    {
      mode = ["n" "x" "o"];
      key = "[a";
      action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_previous_start('@parameter.inner', 'textobjects') end";
      options.desc = "Prev parameter";
    }

    # grug-far: project-wide search & replace (LazyVim's <leader>sr).
    {
      mode = "n";
      key = "<leader>sr";
      action.__raw = "function() require('grug-far').open() end";
      options.desc = "Search & replace (grug-far)";
    }

    # ── dial: increment/decrement under cursor ──
    {
      mode = "n";
      key = "<C-a>";
      action.__raw = "function() require('dial.map').manipulate('increment', 'normal') end";
      options.desc = "Increment";
    }
    {
      mode = "n";
      key = "<C-x>";
      action.__raw = "function() require('dial.map').manipulate('decrement', 'normal') end";
      options.desc = "Decrement";
    }
    {
      mode = "x";
      key = "<C-a>";
      action.__raw = "function() require('dial.map').manipulate('increment', 'visual') end";
      options.desc = "Increment";
    }
    {
      mode = "x";
      key = "<C-x>";
      action.__raw = "function() require('dial.map').manipulate('decrement', 'visual') end";
      options.desc = "Decrement";
    }
    {
      mode = "x";
      key = "g<C-a>";
      action.__raw = "function() require('dial.map').manipulate('increment', 'gvisual') end";
      options.desc = "Increment (cumulative)";
    }
    {
      mode = "x";
      key = "g<C-x>";
      action.__raw = "function() require('dial.map').manipulate('decrement', 'gvisual') end";
      options.desc = "Decrement (cumulative)";
    }

    # ── yanky: route yank/paste through the ring, then cycle history ──
    {
      mode = ["n" "x"];
      key = "y";
      action = "<Plug>(YankyYank)";
      options.desc = "Yank (yanky)";
      options.remap = true;
    }
    {
      mode = ["n" "x"];
      key = "p";
      action = "<Plug>(YankyPutAfter)";
      options.desc = "Put after (yanky)";
      options.remap = true;
    }
    {
      mode = ["n" "x"];
      key = "P";
      action = "<Plug>(YankyPutBefore)";
      options.desc = "Put before (yanky)";
      options.remap = true;
    }
    {
      mode = "n";
      key = "<C-p>";
      action = "<Plug>(YankyPreviousEntry)";
      options.desc = "Cycle to previous yank";
      options.remap = true;
    }
    {
      mode = "n";
      key = "<C-n>";
      action = "<Plug>(YankyNextEntry)";
      options.desc = "Cycle to next yank";
      options.remap = true;
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
}
