{
  # LSP + completion + formatting/linting FRAMEWORK. The individual language
  # servers, formatters, and linters live in ./languages/<lang>.nix — each file
  # owns its full stack so a language is added/removed in one place. This module
  # holds only the cross-cutting setup and the language-agnostic keymaps.
  plugins = {
    # Crowd-sourced JSON/YAML schema catalog. jsonls/yamlls (in ./languages)
    # auto-wire their `schemas` to it when it's present.
    schemastore.enable = true;

    lsp.enable = true;

    blink-cmp = {
      enable = true;
      settings = {
        # super-tab: <Tab> accepts the completion (and jumps snippets);
        # <S-Tab> goes back. <C-n>/<C-p>/arrows still navigate the menu.
        keymap.preset = "super-tab";
        sources.default = ["lsp" "path" "snippets" "buffer"];
        completion.documentation.auto_show = true;
      };
    };

    # Community snippet library (VSCode format). blink's `snippets` source
    # above discovers it on the runtimepath automatically; this just supplies
    # the snippet content.
    friendly-snippets.enable = true;

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

  # Turn on inlay hints for every server that emits them (nixd package
  # versions, gopls types, etc.)
  autoCmd = [
    {
      event = "LspAttach";
      desc = "Enable inlay hints when an LSP client supports them";
      callback.__raw = ''
        function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
          end
        end
      '';
    }
  ];

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
    # Use Neovim 0.11's native `gr*` keys (better ecosystem support, no bare-`gr`
    # timeoutlen delay) but route them to Snacks pickers for the nicer UI. These
    # override the builtin grr/gri/grt; grn (rename) + gra (code action) keep
    # their defaults (also bound to <leader>cr / <leader>ca below).
    {
      mode = "n";
      key = "grr";
      action = "<cmd>lua Snacks.picker.lsp_references()<cr>";
      options.desc = "References";
    }
    {
      mode = "n";
      key = "gri";
      action = "<cmd>lua Snacks.picker.lsp_implementations()<cr>";
      options.desc = "Goto implementation";
    }
    {
      mode = "n";
      key = "grt";
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
    # Generic organize-imports via the standard LSP code action. Works for any
    # server that implements it (gopls, ruff, ts_ls). On Java buffers the
    # buffer-local nvim-jdtls map (languages/java.nix) overrides this.
    {
      mode = "n";
      key = "<leader>co";
      action.__raw = ''
        function()
          vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } }, apply = true })
        end
      '';
      options.desc = "Organize Imports";
    }
    {
      mode = "n";
      key = "K";
      action.__raw = "vim.lsp.buf.hover";
      options.desc = "Hover";
    }
    # `:LspRestart` misses jdtls (nvim-jdtls bypasses lspconfig) — and jdtls is
    # the one that wedges. Re-fire FileType to re-attach without a buffer reload,
    # so unsaved edits survive.
    {
      mode = "n";
      key = "<leader>cR";
      action.__raw = ''
        function()
          local bufnr = vim.api.nvim_get_current_buf()
          local ft = vim.bo[bufnr].filetype
          local clients = vim.lsp.get_clients({ bufnr = bufnr })
          if vim.tbl_isempty(clients) then
            vim.notify("No LSP client to restart", vim.log.levels.WARN)
            return
          end
          local names = table.concat(
            vim.tbl_map(function(c) return c.name end, clients), ", "
          )
          for _, client in ipairs(clients) do
            client:stop(true)
          end
          vim.defer_fn(function()
            vim.api.nvim_exec_autocmds("FileType", { pattern = ft })
          end, 500)
          vim.notify("Restarting LSP: " .. names, vim.log.levels.INFO)
        end
      '';
      options.desc = "Restart LSP";
    }
  ];
}
