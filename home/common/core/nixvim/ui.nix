{
  colors,
  lib,
  muted,
  pkgs,
  self,
  sshSettings ? {},
  ...
}: let
  # snacks.gitbrowse remote → web-URL patterns. Derive alias→HostName rewrites
  # from the SSH config so gitbrowse resolves aliased remotes to real URLs, then
  # append snacks' upstream defaults (it replaces this list wholesale and applies
  # every entry in order). Anchoring to `@alias[:/]` avoids mangling repo paths.
  luaEscape =
    builtins.replaceStrings
    ["%" "(" ")" "." "+" "-" "*" "?" "[" "]" "^" "$"]
    ["%%" "%(" "%)" "%." "%+" "%-" "%*" "%?" "%[" "%]" "%^" "%$"];
  sshAliasRewrites = lib.filter (p: p != null) (lib.mapAttrsToList (name: entry: let
    data = entry.data or entry;
    hostName = data.HostName or null;
    header = data.header or "Host ${name}";
    # First single, non-wildcard token after `Host ` (skips Match/`*` blocks).
    m = builtins.match "Host ([^ ?*]+).*" header;
    alias =
      if m == null
      then null
      else builtins.head m;
  in
    if hostName != null && alias != null && alias != hostName
    then ["@${luaEscape alias}([:/])" "@${hostName}%1"]
    else null)
  sshSettings);
  gitbrowseRemotePatterns =
    sshAliasRewrites
    ++ [
      ["^(https?://.*)%.git$" "%1"]
      ["^git@(.+):(.+)%.git$" "https://%1/%2"]
      ["^git@(.+):(.+)$" "https://%1/%2"]
      ["^git@(.+)/(.+)$" "https://%1/%2"]
      ["^org%-%d+@(.+):(.+)%.git$" "https://%1/%2"]
      ["^ssh://git@(.*)$" "https://%1"]
      ["^ssh://([^:/]+)(:%d+)/(.*)$" "https://%1/%3"]
      ["^ssh://([^/]+)/(.*)$" "https://%1/%2"]
      ["ssh%.dev%.azure%.com/v3/(.*)/(.*)$" "dev.azure.com/%1/_git/%2"]
      ["^https://%w*@(.*)" "https://%1"]
      ["^git@(.*)" "https://%1"]
      [":%d+" ""]
      ["%.git$" ""]
    ];

  # Files hidden from the explorer + pickers — mirrors what we hide in VSCode
  # (files.exclude / search.exclude): build artifacts, caches, venvs, IDE
  # metadata. Dotfiles themselves still show (hidden = true); these prune junk.
  pickerExclude = [
    "node_modules"
    ".git"
    "dist"
    "build"
    "bin"
    "result"
    ".next"
    ".nuxt"
    ".turbo"
    "coverage"
    ".coverage"
    "htmlcov"
    ".direnv"
    ".devenv"
    ".venv"
    "**/venv"
    "__pycache__"
    ".mypy_cache"
    ".pytest_cache"
    ".ruff_cache"
    ".tox"
    "*.egg-info"
    ".gradle"
    ".settings"
    ".classpath"
    ".project"
    ".factorypath"
    ".kls_database.db"
    "dump.rdb"
    ".pre-commit-config.yaml"
  ];
in {
  # LazyVim-style UI layer. No colorscheme — stylix's nixvim target themes
  # everything from the catppuccin-mocha base16 palette automatically.

  # stylix maps Comment to base03, too dim to read against base00 or CursorLine.
  # highlightOverride re-applies on ColorScheme so it survives stylix's theme.
  highlightOverride = {
    Comment.fg = muted.text;
    "@comment".fg = muted.text;
    # flash.nvim (`s`): leave the match highlights at flash's defaults and only
    # recolour the jump label (the key you press) so it's easy to spot — red
    # badge on the base00 background.
    FlashLabel = {
      fg = colors.base00;
      bg = colors.base08; # red
      bold = true;
    };
    # Visible current line; also marks the open file in the explorer (follow_file
    # parks the unfocused selection there, rendered with CursorLine).
    CursorLine.bg = colors.base02;
    # gitsigns links this to NonText (base03), which only ever renders on the
    # CursorLine set above — low enough that ghostty's minimum-contrast recolours it.
    # Needs muted.text specifically: muted.ui doesn't clear 4.5:1 on base02.
    GitSignsCurrentLineBlame.fg = muted.text;
    # snacks pickers, dashboard and notifier all link their dim text to NonText,
    # so base03 makes ignored/untracked entries unreadable. listchars is unset,
    # leaving the ~ filler as the only caller that wants it near-invisible.
    NonText.fg = muted.ui;
    EndOfBuffer.fg = colors.base01;
    LineNr.fg = muted.ui;
    SignColumn.fg = muted.ui;
    CursorLineNr.fg = muted.text;
  };

  # Gives Snacks.explorer a `trash` command so deleting files there is
  # recoverable instead of a permanent `rm`.
  extraPackages = [pkgs.trash-cli];

  # On the runtimepath so `require("nix-logo-3d")` resolves.
  extraPlugins = [pkgs.nix-logo-3d];

  plugins = {
    # Material Design Icon glyphs instead of the default devicons set, matching
    # the file-icon theme already used elsewhere (vscode/extensions/core/material-icons.nix).
    # Same module name ("nvim-web-devicons"), different package.
    web-devicons = {
      enable = true;
      package = pkgs.nvim-material-icon;
      settings.default = true;
    };

    # VSCode-style smooth caret: animates a trailing smear as the cursor jumps.
    smear-cursor = {
      enable = true;
      settings = {
        smear_between_buffers = true;
        smear_between_neighbor_lines = true;
      };
    };

    lualine = {
      enable = true;
      settings.options.globalstatus = true;
    };

    bufferline = {
      enable = true;
      settings.options = {
        diagnostics = "nvim_lsp";
        always_show_bufferline = false;
        # bufferline's toggle counts only buffers — it hides the bar (and tab
        # indicators) at 1 buffer even with many tabs. Off => the autoCmd drives it.
        auto_toggle_bufferline = false;
      };
    };

    which-key = {
      enable = true;
      # diffview tags its ~18 z-fold passthrough maps with desc="diffview_ignore"
      # to hide them from its own help; which-key shows the sentinel verbatim.
      settings.filter.__raw = ''function(mapping) return mapping.desc ~= "diffview_ignore" end'';
      settings.spec = [
        {
          __unkeyed-1 = "<leader>a";
          group = "ai";
        }
        {
          __unkeyed-1 = "<leader>b";
          group = "buffer";
        }
        {
          __unkeyed-1 = "<leader>c";
          group = "code";
        }
        {
          __unkeyed-1 = "<leader>d";
          group = "debug";
        }
        {
          __unkeyed-1 = "<leader>f";
          group = "file/find";
        }
        {
          __unkeyed-1 = "<leader>g";
          group = "git";
        }
        {
          __unkeyed-1 = "<leader>gh";
          group = "hunks";
        }
        {
          __unkeyed-1 = "<leader>gm";
          group = "gitlab mr";
        }
        {
          __unkeyed-1 = "<leader>ac";
          group = "codecompanion";
        }
        {
          __unkeyed-1 = "<leader><tab>";
          group = "tabs";
        }
        {
          __unkeyed-1 = "<leader>w";
          group = "windows";
        }
        {
          __unkeyed-1 = "<leader>q";
          group = "quit/session";
        }
        {
          __unkeyed-1 = "<leader>s";
          group = "search";
        }
        {
          __unkeyed-1 = "<leader>t";
          group = "test";
        }
        {
          __unkeyed-1 = "<leader>u";
          group = "ui";
        }
        {
          __unkeyed-1 = "<leader>x";
          group = "diagnostics/quickfix";
        }
      ];
    };

    # Indent guides come from snacks.indent (configured in the snacks block
    # below) — the LazyVim default — so indent-blankline is intentionally off.

    # noice moves the `:` command line into a centered "command palette" popup
    # (with blink's command completion rendered inside it) and tidies messages.
    # snacks.notifier owns notifications, so noice's own notify view is off to
    # avoid doubling them.
    noice = {
      enable = true;
      settings = {
        notify.enabled = false;
        lsp.signature.enabled = true;
        presets = {
          command_palette = true; # cmdline + completion menu together, top-center
          bottom_search = true; # keep `/` search at the bottom
          long_message_to_split = true;
        };
      };
    };

    # snacks provides dashboard + notifier AND the file explorer + picker —
    # modern LazyVim's defaults (no neo-tree / fzf-lua). One plugin family for
    # find-files, grep, buffers, LSP pickers, and the file tree.
    snacks = {
      enable = true;
      settings = {
        bigfile.enabled = true;
        notifier.enabled = true;
        dashboard = {
          enabled = true;
          preset = {
            # LazyVim-style quick actions wired to our snacks pickers / binds.
            keys = [
              {
                icon = " ";
                key = "f";
                desc = "Find file";
                action = ":lua Snacks.dashboard.pick('files')";
              }
              {
                icon = " ";
                key = "n";
                desc = "New file";
                action = ":ene | startinsert";
              }
              {
                icon = " ";
                key = "r";
                desc = "Recent files";
                action = ":lua Snacks.dashboard.pick('oldfiles')";
              }
              {
                icon = " ";
                key = "g";
                desc = "Find text";
                action = ":lua Snacks.dashboard.pick('live_grep')";
              }
              {
                icon = " ";
                key = "e";
                desc = "Explorer";
                action = ":lua Snacks.explorer()";
              }
              {
                icon = " ";
                key = "c";
                desc = "nix-config";
                action = ":lua Snacks.picker.files({ cwd = vim.fn.expand('~/nix-config') })";
              }
              {
                icon = " ";
                key = "s";
                desc = "Restore session";
                action = ":lua require('persistence').load()";
              }
              {
                icon = " ";
                key = "q";
                desc = "Quit";
                action = ":qa";
              }
            ];
          };
          # No `startup` section: it needs lazy.nvim's lazy.stats, which nixvim
          # has no equivalent of, so it throws.
          sections = [
            {
              # Animated 3D nix snowflake; the module owns its height and timer.
              __raw = ''require("nix-logo-3d").section({padding = 1})'';
            }
            {
              text.__raw = "vim.fn.hostname()";
              align = "center";
              padding = 1;
            }
            {
              section = "keys";
              gap = 1;
              padding = 1;
            }
            {
              section = "recent_files";
              padding = 1;
            }
            {section = "projects";}
          ];
        };
        quickfile.enabled = true;
        words.enabled = true;
        explorer.enabled = true;
        # LazyVim UI polish: indent guides + animated scope highlight, smooth
        # scrolling, and the rich status column (fold/sign/number gutter).
        indent.enabled = true;
        scope.enabled = true;
        scroll.enabled = true;
        statuscolumn.enabled = true;
        # Derived from the SSH config (see `let` above) so host aliases stay in sync.
        gitbrowse.remote_patterns = gitbrowseRemotePatterns;
        picker = {
          enabled = true;
          hidden = true; # show dotfiles in pickers (e.g. .gitlab-ci.yml)
          sources = {
            # Single-child folder auto-descend lives in
            # ./snacks/explorer-nesting.nix (delete it when snacks gains a
            # native group_empty option).
            explorer = {
              hidden = true;
              # Show gitignored paths (.sdd, build output) in the tree; the
              # `exclude` list is the only thing that hides files here. Scoped to
              # the explorer so grep/files keep respecting .gitignore (no
              # node_modules flood).
              ignored = true;
              exclude = pickerExclude;
            };
            files.exclude = pickerExclude;
          };
        };
      };
    };
  };

  autoCmd = [
    {
      # Show the tabline on >1 listed buffer OR >1 tab. Deferred so BufDelete's
      # count settles before we read it.
      event = ["BufAdd" "BufDelete" "TabNew" "TabClosed" "TabEnter" "BufEnter" "VimEnter"];
      callback.__raw = ''
        function()
          vim.schedule(function()
            local bufs = 0
            for _, b in ipairs(vim.api.nvim_list_bufs()) do
              if vim.bo[b].buflisted then bufs = bufs + 1 end
            end
            vim.o.showtabline = (bufs > 1 or #vim.api.nvim_list_tabpages() > 1) and 2 or 0
          end)
        end
      '';
    }
  ];

  keymaps = [
    {
      mode = "n";
      key = "<leader>sK";
      action.__raw = ''function() vim.ui.open("${self}/docs/guides/nixvim-keybinds.html") end'';
      options.desc = "Keybind guide (browser)";
    }
  ];
}
