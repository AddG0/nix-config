{pkgs, ...}: {
  programs.nixvim = {
    plugins.lsp.servers.marksman.enable = true;
    plugins.render-markdown.enable = true;
    plugins.markdown-preview.enable = true;
    plugins.lint = {
      lintersByFt.markdown = ["markdownlint"];
      # The linter is named `markdownlint`, its package is markdownlint-cli.
      autoInstall.overrides.markdownlint = pkgs.markdownlint-cli;
    };
  };
}
