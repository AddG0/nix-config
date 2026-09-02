{
  config,
  lib,
  ...
}: {
  # LazyVim-style editor defaults. Leader/clipboard live in ./default.nix;
  # theming is handled by stylix (stylix.targets.nixvim), so no colorscheme is
  # set here.
  globals.maplocalleader = "\\";

  opts = {
    autowrite = true;
    completeopt = "menu,menuone,noselect";
    conceallevel = 2;
    confirm = true;
    cursorline = true;
    # 0.12 defaults + histogram (beats myers on moved blocks); linematch 40→60 for larger restructures.
    diffopt = "internal,filler,closeoff,indent-heuristic,inline:char,linematch:60,algorithm:histogram";
    expandtab = true;
    # Folding is owned by nvim-origami (editor.nix): it sets foldexpr to LSP
    # folds with a treesitter fallback and auto-collapses imports on open
    # (IntelliJ-style — class at the top). foldlevel 99 = everything open by
    # default, so only imports get folded.
    foldlevel = 99;
    foldlevelstart = 99;
    formatoptions = "jcroqlnt";
    grepformat = "%f:%l:%c:%m";
    grepprg = "rg --vimgrep";
    ignorecase = true;
    inccommand = "nosplit";
    laststatus = 3;
    list = true;
    mouse = "a";
    number = true;
    relativenumber = true;
    pumblend = 10;
    pumheight = 10;
    scrolloff = 4;
    sidescrolloff = 8;
    shiftround = true;
    shiftwidth = 2;
    signcolumn = "yes";
    smartcase = true;
    smartindent = true;
    splitbelow = true;
    splitkeep = "screen";
    splitright = true;
    # Drop `blank` (and `options`) from the default sessionoptions so restoring
    # a session (persistence.nvim, <leader>ql) doesn't recreate empty plugin
    # windows like the left-docked Snacks explorer — fixes the stray empty left
    # window. Matches LazyVim's recommended set.
    sessionoptions = "buffers,curdir,tabpages,winsize,help,globals,skiprtp,folds";
    tabstop = 2;
    termguicolors = true;
    # window title: "<folder> – <file>", folder alone on no-name buffers
    title = true;
    titlestring = "%{fnamemodify(getcwd(), ':t') . (expand('%:t') != '' ? ' – ' . expand('%:t') : '')}";
    timeoutlen = 300;
    undofile = true;
    undolevels = 10000;
    updatetime = 200;
    virtualedit = "block";
    wildmode = "longest:full,full";
    winminwidth = 5;
    wrap = false;
  };

  # autoread (on by default) only reloads externally-changed files when a
  # timestamp check runs, which Neovim doesn't do on its own. Run `:checktime`
  # on focus/buffer-enter so files changed on disk (git checkout, formatters,
  # another editor) reload automatically. Pairs with tmux `focus-events on`,
  # which forwards FocusGained into nvim. (LazyVim ships the same autocmd.)
  autoCmd = [
    {
      event = ["FocusGained" "BufEnter" "TermClose" "TermLeave"];
      command = "checktime";
    }
    # In a picker jump the modal swap prompt can't take input and aborts (E5108);
    # resolve it non-interactively — open anyway, notify in case it's live elsewhere.
    {
      event = ["SwapExists"];
      callback.__raw = ''
        function(ev)
          vim.v.swapchoice = "e"
          vim.schedule(function()
            vim.notify("Swap file existed for " .. (ev.file or "?") .. " — opened anyway", vim.log.levels.WARN)
          end)
        end
      '';
    }
    # Soft-wrap prose at word boundaries (code stays nowrap via the global opt).
    {
      event = ["FileType"];
      pattern = ["markdown" "text" "gitcommit"];
      command = "setlocal wrap linebreak";
    }
    # Vim remembers window options per (window, buffer), falling back to the last
    # closed window that showed the buffer (`:h local-options`).
    {
      event = ["BufWinEnter"];
      desc = "Restore window options a stripped-down window left on the buffer";
      callback.__raw = ''
        function(ev)
          if vim.bo[ev.buf].buftype ~= "" then
            return
          end
          -- per buffer by design: markdown's `setlocal wrap linebreak` above,
          -- render-markdown's conceallevel, origami's collapsed imports
          local ft_owned = {wrap = true, conceallevel = true, foldlevel = true}
          -- foldcolumn and winhighlight get stripped by plugins that leave the
          -- global at Vim's default, so name them alongside whatever `opts` declares
          local owned = {foldcolumn = true, winhighlight = true, ${
          lib.concatMapStringsSep ", " (name: "${name} = true") (builtins.attrNames config.opts)
        }}
          local reset = {}
          for name, info in pairs(vim.api.nvim_get_all_options_info()) do
            if
              info.scope == "win"
              and not info.global_local
              and not ft_owned[name]
              -- a non-default global was set deliberately, by `opts` or a plugin
              and (owned[name] or vim.api.nvim_get_option_value(name, {scope = "global"}) ~= info.default)
            then
              reset[#reset + 1] = name
            end
          end
          -- a picker or explorer pushes a file into a window while its own stays
          -- focused, so the window that took the buffer is often not the current one
          for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
            -- floats, diffs (see git.nix) and picker previews own their own look
            local styled = vim.api.nvim_win_get_config(win).relative ~= ""
              or vim.wo[win].diff
              or vim.w[win].snacks_picker_preview
            if not styled then
              for _, name in ipairs(reset) do
                -- nil drops the local value back to the global, not to Vim's default
                vim.api.nvim_set_option_value(name, nil, {win = win, scope = "local"})
              end
            end
          end
        end
      '';
    }
  ];
}
