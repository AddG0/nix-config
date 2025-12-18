{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.golang.go
  ];
  userSettings = {
    "go.useLanguageServer" = true;
    "go.lintTool" = "golangci-lint";
    "go.lintOnSave" = "package";
    "go.formatTool" = "goimports";
    "gopls" = {
      "ui.semanticTokens" = true;
      "ui.completion.usePlaceholders" = true;
    };
  };
}
