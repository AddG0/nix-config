{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace-release.bradlc.vscode-tailwindcss
  ];
  userSettings = {
    "tailwindCSS.emmetCompletions" = true;
    "tailwindCSS.includeLanguages" = {
      "javascript" = "javascript";
      "javascriptreact" = "javascript";
      "typescript" = "javascript";
      "typescriptreact" = "javascript";
      "html" = "html";
    };
    "editor.quickSuggestions" = {
      "strings" = true;
    };
  };
}
