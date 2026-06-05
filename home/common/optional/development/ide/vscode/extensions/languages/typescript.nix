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

    # TypeScript / JavaScript
    "js/ts.updateImportsOnFileMove.enabled" = "always";
    "js/ts.suggest.autoImports" = true;
    "js/ts.inlayHints.parameterNames.enabled" = "all";
    "js/ts.inlayHints.functionLikeReturnTypes.enabled" = true;
    "js/ts.tsserver.npm.path" = "${pkgs.nodejs}/bin/npm";
    "js/ts.tsserver.node.path" = "${pkgs.nodejs}/bin/node";

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
