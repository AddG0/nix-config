{
  # LazyVim-style editor defaults. Leader/clipboard live in ./default.nix;
  # theming is handled by stylix (stylix.targets.nixvim), so no colorscheme is
  # set here.
  programs.nixvim = {
    globals.maplocalleader = "\\";

    opts = {
      autowrite = true;
      completeopt = "menu,menuone,noselect";
      conceallevel = 2;
      confirm = true;
      cursorline = true;
      expandtab = true;
      # Solid fill for diff filler/deleted lines instead of the default `-`
      # dashes, so diffs (diffview) render clean red/green bars.
      fillchars = {
        diff = " ";
      };
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
  };
}
