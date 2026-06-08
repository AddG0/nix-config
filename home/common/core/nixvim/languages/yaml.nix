{
  # yamlls auto-wires to SchemaStore.nvim (../lsp.nix) — that's what gives
  # .gitlab-ci.yml, k8s, GitHub Actions, etc. their schemas. yamllint comes
  # from lint's autoInstall.
  programs.nixvim = {
    plugins.lsp.servers.yamlls.enable = true;
    plugins.lint.lintersByFt.yaml = ["yamllint"];
  };
}
