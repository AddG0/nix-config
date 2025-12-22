{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.golang.go
  ];
  userSettings = {
    # Point to Nix-provided Go
    "go.goroot" = "${pkgs.go}/share/go";
    "go.useLanguageServer" = true;
    "go.lintTool" = "golangci-lint";
    "go.lintOnSave" = "package";
    "go.formatTool" = "goimports";
    "go.alternateTools" = {
      "go" = "${pkgs.go}/bin/go";
      "gopls" = "${pkgs.gopls}/bin/gopls";
      "golangci-lint" = "${pkgs.golangci-lint}/bin/golangci-lint";
      "goimports" = "${pkgs.gotools}/bin/goimports";
      "dlv" = "${pkgs.delve}/bin/dlv";
    };
    "gopls" = {
      "ui.semanticTokens" = true;
      "ui.completion.usePlaceholders" = true;
    };
  };
}
