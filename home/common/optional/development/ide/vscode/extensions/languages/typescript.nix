{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.dbaeumer.vscode-eslint
    pkgs.vscode-marketplace.orta.vscode-jest
    pkgs.vscode-marketplace.vitest.explorer
  ];
  userSettings = {
    # ESLint
    "eslint.enable" = true;
    "eslint.validate" = ["javascript" "javascriptreact" "typescript" "typescriptreact"];

    # TypeScript
    "typescript.updateImportsOnFileMove.enabled" = "always";
    "typescript.suggest.autoImports" = true;
    "typescript.inlayHints.parameterNames.enabled" = "all";
    "typescript.inlayHints.functionLikeReturnTypes.enabled" = true;
    "typescript.npm" = "${pkgs.nodejs}/bin/npm";
    "typescript.tsserver.nodePath" = "${pkgs.nodejs}/bin/node";

    # Hide Node.js build directories from explorer
    "files.exclude" = {
      "**/node_modules" = true;
      "**/dist" = true;
      "**/build" = true;
      "**/.next" = true;
      "**/.nuxt" = true;
      "**/.turbo" = true;
      "**/coverage" = true;
    };

    # Exclude from search
    "search.exclude" = {
      "**/node_modules" = true;
      "**/dist" = true;
      "**/build" = true;
      "**/.next" = true;
      "**/.nuxt" = true;
      "**/.turbo" = true;
      "**/coverage" = true;
    };

    # Jest
    "jest.runMode" = "on-demand";
  };
}
