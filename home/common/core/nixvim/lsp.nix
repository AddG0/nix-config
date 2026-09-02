{
  # LSP + completion + formatting/linting FRAMEWORK. The individual language
  # servers, formatters, and linters live in ./languages/<lang>.nix — each file
  # owns its full stack so a language is added/removed in one place. This module
  # holds only the cross-cutting setup and the language-agnostic keymaps.

  # Inline diagnostics — Neovim shows only signs + underline by default.
  diagnostic.settings.virtual_text = true;

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

    # Formatter framework. autoInstall adds each formatter package by name (like
    # lint above), so ./languages files only declare formatters_by_ft — no manual
    # extraPackages. This sets the always-on fallback + format-on-save behaviour.
    conform-nvim = {
      enable = true;
      autoInstall.enable = true;
      settings = {
        formatters_by_ft."_" = ["trim_whitespace"];
        format_on_save = {
          lsp_format = "fallback";
          timeout_ms = 1000;
        };
      };
    };
  };

  # FLAKE-UPDATE: drop once our pinned Neovim fixes the changetracking nil-deref
  # (neovim/neovim#37814, #28987 — open as of 0.12.3). When a client stays attached
  # to a buffer whose changetracking state was already torn down (detaching clients
  # from diffview:// blob buffers in the LspAttach autocmd below is one trigger),
  # `send_changes` dereferences a nil `buf_state` and crashes diffview's render.
  # The guard skips only that nil case and re-raises everything else.
  extraConfigLua = ''
    do
      local ct = require("vim.lsp._changetracking")
      if not ct.__buf_state_guard then
        ct.__buf_state_guard = true
        local orig = ct.send_changes
        ct.send_changes = function(...)
          local ok, err = pcall(orig, ...)
          if not ok and not tostring(err):find("buf_state", 1, true) then
            error(err)
          end
        end
      end
    end

    -- One global call covers every buffer: client.lua re-reads this marker on
    -- each client→buffer attach, and the capability debounces its own refresh.
    vim.lsp.codelens.enable(true)

    -- Filters to clients supporting prepareTypeHierarchy and pins the follow-up
    -- request to that client (core's vim.lsp.buf.typehierarchy does the same,
    -- runtime/lua/vim/lsp/buf.lua) — a plain buf_request broadcast fails here:
    -- an unrelated attached client (typos_lsp) answers prepare with nothing
    -- first, and that "no result" wins the race before jdtls's real one arrives.
    --
    -- quickfixtextfunc overrides the whole rendered line, not just `text`: the
    -- quickfix window always leads with `filename`, and vim.uri_to_fname() on
    -- jdtls' synthetic jdt:// URIs (jar/JDK contents) is an unreadable blob.
    function _G.LspTypeHierarchy(kind)
      local method = "typeHierarchy/" .. kind
      local bufnr = vim.api.nvim_get_current_buf()
      local clients = vim.lsp.get_clients({bufnr = bufnr, method = "textDocument/prepareTypeHierarchy"})
      if #clients == 0 then
        vim.notify("No LSP client here supports type hierarchy", vim.log.levels.WARN)
        return
      end

      local function show(client_id, item)
        local client = assert(vim.lsp.get_client_by_id(client_id))
        client:request(method, {item = item}, function(_, items)
          if not items or #items == 0 then
            vim.notify("No " .. kind, vim.log.levels.INFO)
            return
          end
          local qf = vim.tbl_map(function(it)
            return {
              filename = vim.uri_to_fname(it.uri),
              lnum = it.range.start.line + 1,
              col = it.range.start.character + 1,
              text = (it.detail and it.detail ~= "" and (it.detail .. ".") or "") .. it.name,
            }
          end, items)
          vim.fn.setqflist({}, " ", {
            title = "Type " .. kind,
            items = qf,
            quickfixtextfunc = function(info)
              local list = vim.fn.getqflist({id = info.id, items = 1}).items
              local lines = {}
              for i = info.start_idx, info.end_idx do
                lines[#lines + 1] = list[i].text
              end
              return lines
            end,
          })
          vim.cmd("copen")
        end, bufnr)
      end

      local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
      local pending, found = #clients, {}
      for _, client in ipairs(clients) do
        client:request("textDocument/prepareTypeHierarchy", params, function(_, result)
          pending = pending - 1
          for _, item in ipairs(result or {}) do
            found[#found + 1] = {client.id, item}
          end
          if pending > 0 then
            return
          elseif #found == 0 then
            vim.notify("No type hierarchy item here", vim.log.levels.INFO)
          elseif #found == 1 then
            show(found[1][1], found[1][2])
          else
            vim.ui.select(found, {
              prompt = "Select a type hierarchy item:",
              format_item = function(x) return x[2].name end,
            }, function(x)
              if x then show(x[1], x[2]) end
            end)
          end
        end, bufnr)
      end
    end
  '';

  autoCmd = [
    {
      event = "LspAttach";
      desc = "Keep LSP off non-file buffers; enable inlay hints on real files";
      callback.__raw = ''
        function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then return end
          local uri = vim.uri_from_bufnr(args.buf)
          -- clangd-derived servers (nixd) reject non-file:// URIs with -32602 — e.g.
          -- diffview/gitsigns/neogit/picker previews and `nofile` scratch buffers.
          -- diffview also hands over real file:// URIs carrying a synthetic revision
          -- segment (…/.git/:0:/src/foo.rs), which the scheme test alone lets through.
          if vim.bo[args.buf].buftype ~= ""
            or not vim.startswith(uri, "file://")
            or uri:find("/%.git/") then
            -- Doesn't stick: Client:on_attach re-marks the buffer attached after the
            -- autocmd returns. Servers that break on non-file URIs are gated before
            -- attach instead (nixd, marksman in ./languages).
            vim.lsp.buf_detach_client(args.buf, client.id)
            -- Capabilities are re-inited in a vim.schedule without re-testing attachment.
            vim.lsp.codelens.enable(false, { bufnr = args.buf })
            return
          end
          if client:supports_method("textDocument/inlayHint") then
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
      key = "<leader>cc";
      action.__raw = "function() vim.lsp.codelens.run() end";
      options.desc = "Run CodeLens";
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
          local ids = vim.tbl_map(function(c) return c.id end, clients)
          for _, client in ipairs(clients) do
            -- SIGTERM-ing jdtls mid index-write corrupts its workspace and wedges
            -- it on the next start.
            client:stop(5000)
          end
          -- A fixed delay can re-attach before the old client has exited.
          local tries = 0
          local function reattach()
            tries = tries + 1
            local live = vim.iter(ids):any(function(id)
              return vim.lsp.get_client_by_id(id) ~= nil
            end)
            if live and tries < 50 then -- 10s cap, must outlast the stop() escalation
              vim.defer_fn(reattach, 200)
              return
            end
            vim.api.nvim_exec_autocmds("FileType", { pattern = ft })
          end
          vim.defer_fn(reattach, 200)
          vim.notify("Restarting LSP: " .. names, vim.log.levels.INFO)
        end
      '';
      options.desc = "Restart LSP";
    }
    # IntelliJ-style Type Hierarchy: walk up to supertypes / down to subtypes.
    # LspTypeHierarchy (extraConfigLua above), results in the quickfix list (<leader>xq).
    {
      mode = "n";
      key = "<leader>ch";
      action.__raw = ''function() _G.LspTypeHierarchy("supertypes") end'';
      options.desc = "Supertypes (hierarchy up)";
    }
    {
      mode = "n";
      key = "<leader>cH";
      action.__raw = ''function() _G.LspTypeHierarchy("subtypes") end'';
      options.desc = "Subtypes (hierarchy down)";
    }
  ];
}
