{
  # TypeScript / JavaScript.
  programs.nixvim.plugins = {
    lsp.servers.ts_ls.enable = true;
    neotest.adapters.jest.enable = true; # jest test runner (framework: ../testing.nix)
  };
}
