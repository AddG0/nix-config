{pkgs, ...}: {
  plugins.lsp.servers.gopls.enable = true;
  plugins.conform-nvim.settings.formatters_by_ft.go = ["goimports"];
  plugins.dap-go.enable = true; # debugging via delve
  plugins.neotest.adapters.golang.enable = true; # go test runner (framework: ../testing.nix)
  extraPackages = [pkgs.delve]; # dlv debugger
}
