{
  # LSP + completion + formatting/linting FRAMEWORK. The individual language
  # servers, formatters, and linters live in ./languages/<lang>.nix — each file
  # owns its full stack so a language is added/removed in one place. This module
  # holds only the cross-cutting setup and the language-agnostic keymaps.
  programs.nixvim = {
    plugins = {
      # Crowd-sourced JSON/YAML schema catalog. jsonls/yamlls (in ./languages)
      # auto-wire their `schemas` to it when it's present.
      schemastore.enable = true;

      lsp.enable = true;

      blink-cmp = {
        enable = true;
        settings = {
          keymap.preset = "default";
          sources.default = ["lsp" "path" "snippets" "buffer"];
          completion.documentation.auto_show = true;
        };
      };

      # Linter framework. autoInstall adds each linter package by name (like the
      # LSP servers), so ./languages files only declare lintersByFt — no manual
      # extraPackages. nixvim sets up the lint-on-write autocmd by default.
      lint = {
        enable = true;
        autoInstall.enable = true;
      };

      # Formatter framework. ./languages files add their formatters_by_ft entry;
      # this sets the always-on fallback + format-on-save behaviour.
      conform-nvim = {
        enable = true;
        settings = {
          formatters_by_ft."_" = ["trim_whitespace"];
          format_on_save = {
            lsp_format = "fallback";
            timeout_ms = 1000;
          };
        };
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>cf";
        action.__raw = "function() require('conform').format({ async = true, lsp_format = 'fallback' }) end";
        options.desc = "Format buffer";
      }
      {
        mode = "n";
        key = "gd";
        action = "<cmd>lua Snacks.picker.lsp_definitions()<cr>";
        options.desc = "Goto definition";
      }
      {
        mode = "n";
        key = "gr";
        action = "<cmd>lua Snacks.picker.lsp_references()<cr>";
        options.desc = "References";
      }
      {
        mode = "n";
        key = "gI";
        action = "<cmd>lua Snacks.picker.lsp_implementations()<cr>";
        options.desc = "Goto implementation";
      }
      {
        mode = "n";
        key = "gy";
        action = "<cmd>lua Snacks.picker.lsp_type_definitions()<cr>";
        options.desc = "Goto type definition";
      }
      {
        mode = "n";
        key = "<leader>ca";
        action.__raw = "vim.lsp.buf.code_action";
        options.desc = "Code action";
      }
      {
        mode = "n";
        key = "<leader>cr";
        action.__raw = "vim.lsp.buf.rename";
        options.desc = "Rename";
      }
      {
        mode = "n";
        key = "K";
        action.__raw = "vim.lsp.buf.hover";
        options.desc = "Hover";
      }
    ];
  };
}
