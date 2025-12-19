{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.formulahendry.auto-rename-tag
  ];
  userSettings = {
    "auto-rename-tag.activationOnLanguage" = [
      "html"
      "xml"
      "php"
      "javascript"
      "javascriptreact"
      "typescript"
      "typescriptreact"
      "vue"
      "svelte"
    ];
  };
}
