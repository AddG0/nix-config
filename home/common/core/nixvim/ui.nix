{
  colors,
  lib,
  pkgs,
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
    "venv"
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

  # stylix maps comments to base03 (surface1), and even base04 (surface2,
  # #585b70) is too dim to read on the base00 background — the base16 palette has
  # no lighter grey (base05 is the full text colour, which would make comments
  # indistinguishable from code). So use catppuccin's "overlay2" (#9399b2) — the
  # readable comment tone catppuccin's own themes use, not in the 16-colour set.
  # highlightOverride re-applies on ColorScheme so it survives stylix's theme.
  highlightOverride = {
    Comment.fg = "#9399b2";
    "@comment".fg = "#9399b2";
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
  };

  # Gives Snacks.explorer a `trash` command so deleting files there is
  # recoverable instead of a permanent `rm`.
  extraPackages = [pkgs.trash-cli];

  plugins = {
    web-devicons.enable = true;

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
      };
    };

    which-key = {
      enable = true;
      settings.spec = [
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
            # Logo is a real nix-snowflake PNG rendered with chafa (terminal
            # section below) — crisp on ghostty vs blocky ASCII. Keys are
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
          # The default `startup` section needs lazy.nvim's lazy.stats (absent on
          # nixvim → throws), so use: nix logo (chafa) + hostname + our keys +
          # recent files + projects.
          sections = [
            {
              # chafa renders the PNG as colored half-block symbols (reliable in
              # any terminal). The terminal section spans the full dashboard
              # width (60), so `--align mid,mid` centers the image *inside* chafa
              # (section align doesn't move terminal output). Keep --size's width
              # == dashboard width (60) and tweak --size/height to resize.
              section = "terminal";
              cmd = "${pkgs.chafa}/bin/chafa ${pkgs.nixos-icons}/share/icons/hicolor/1024x1024/apps/nix-snowflake.png --format symbols --symbols vhalf --size 60x16 --align mid,mid; sleep 0.05";
              height = 16;
              padding = 1;
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
          # Don't let .gitignore drive visibility — gitignored paths (.sdd,
          # build output, etc.) should show too. The explicit `exclude` list
          # below is the only thing that hides files.
          ignored = true;
          sources = {
            # Single-child folder auto-descend lives in
            # ./snacks-explorer-nesting.nix (delete it when snacks gains a
            # native group_empty option).
            explorer = {
              hidden = true;
              ignored = true;
              exclude = pickerExclude;
            };
            files.exclude = pickerExclude;
          };
        };
      };
    };
  };
}
