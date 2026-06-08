{config, ...}: let
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
    "dump.rdb"
    ".pre-commit-config.yaml"
  ];
in {
  # LazyVim-style UI layer. No colorscheme — stylix's nixvim target themes
  # everything from the catppuccin-mocha base16 palette automatically.

  # stylix maps comments to base03 (catppuccin "surface1"), which is too dim
  # to read on the base00 background. Bump them to base04 (surface2), the
  # lightest grey in the palette. `highlightOverride` re-applies on ColorScheme
  # so it survives stylix setting the theme.
  programs.nixvim.highlightOverride = {
    Comment.fg = config.lib.stylix.colors.withHashtag.base04;
    "@comment".fg = config.lib.stylix.colors.withHashtag.base04;
  };

  programs.nixvim.plugins = {
    web-devicons.enable = true;

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
          __unkeyed-1 = "<leader>u";
          group = "ui";
        }
        {
          __unkeyed-1 = "<leader>x";
          group = "diagnostics/quickfix";
        }
      ];
    };

    indent-blankline.enable = true;

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
          # Custom sections = the defaults minus `startup`. The startup section
          # does `require('lazy.stats')` to show plugin/startup-time stats, but
          # that module only exists under lazy.nvim — on nixvim it throws and
          # aborts the whole dashboard render. Keep header + keymaps + recent
          # files + projects instead.
          sections = [
            {section = "header";}
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
        picker = {
          enabled = true;
          hidden = true; # show dotfiles in pickers (e.g. .gitlab-ci.yml)
          sources = {
            explorer = {
              hidden = true;
              exclude = pickerExclude;
            };
            files.exclude = pickerExclude;
          };
        };
      };
    };
  };
}
