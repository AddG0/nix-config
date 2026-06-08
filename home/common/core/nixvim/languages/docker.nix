{
  # hadolint (Dockerfile linter) comes from lint's autoInstall (../lsp.nix).
  programs.nixvim = {
    plugins.lsp.servers.dockerls.enable = true;
    plugins.lsp.servers.docker_compose_language_service.enable = true;
    plugins.lint.lintersByFt.dockerfile = ["hadolint"];
  };
}
