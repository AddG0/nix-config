{
  # TypeScript / JavaScript.
  plugins = {
    lsp.servers.ts_ls = {
      enable = true;
      # vim.lsp.inlay_hint.enable only renders hints; ts_ls sends none until these
      # preferences are set (all default off). Mirror both language keys.
      settings = let
        inlayHints = {
          includeInlayParameterNameHints = "all";
          includeInlayParameterNameHintsWhenArgumentMatchesName = false;
          includeInlayFunctionLikeReturnTypeHints = true;
        };
      in {
        typescript = {inherit inlayHints;};
        javascript = {inherit inlayHints;};
      };
    };
    neotest.adapters.jest.enable = true; # jest test runner (framework: ../testing.nix)

    conform-nvim.settings.formatters_by_ft = {
      typescript = ["prettierd"];
      javascript = ["prettierd"];
      typescriptreact = ["prettierd"];
      javascriptreact = ["prettierd"];
    };
  };

  # ts_ls races documentHighlight before its didOpen ("document should be opened
  # first"); drop the capability so illuminate highlights TS via treesitter.
  autoCmd = [
    {
      event = "LspAttach";
      callback.__raw = ''
        function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "ts_ls" then
            client.server_capabilities.documentHighlightProvider = false
          end
        end
      '';
    }
  ];
}
