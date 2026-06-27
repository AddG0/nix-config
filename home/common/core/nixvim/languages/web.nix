{
  # TypeScript / JavaScript.
  plugins = {
    lsp.servers.ts_ls.enable = true;
    neotest.adapters.jest.enable = true; # jest test runner (framework: ../testing.nix)
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
