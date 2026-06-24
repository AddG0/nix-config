{
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
  ];
}
