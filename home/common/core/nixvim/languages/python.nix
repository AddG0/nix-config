{
  # basedpyright for types, ruff as the lint/format LSP, ruff_format via conform.
  # dap-python's adapterPythonPath defaults to python3 + debugpy, so debugging
  # works with no extra config (framework lives in ../dap.nix).
  plugins = {
    lsp.servers.basedpyright.enable = true;
    lsp.servers.ruff.enable = true;
    conform-nvim.settings.formatters_by_ft.python = ["ruff_format"];
    dap-python.enable = true;
    neotest.adapters.python.enable = true; # pytest/unittest runner (framework: ../testing.nix)
  };
}
