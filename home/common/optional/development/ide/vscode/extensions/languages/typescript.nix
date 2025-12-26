{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.dbaeumer.vscode-eslint
    pkgs.vscode-marketplace.esbenp.prettier-vscode
    pkgs.vscode-marketplace.orta.vscode-jest
    pkgs.vscode-marketplace.vitest.explorer
  ];
  userSettings = {
    # ESLint
    "eslint.enable" = true;
    "eslint.validate" = ["javascript" "javascriptreact" "typescript" "typescriptreact"];

    # Prettier
    "prettier.enable" = true;
    "[javascript]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[javascriptreact]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[typescript]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[typescriptreact]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[json]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[html]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[css]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };

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
    "jest.autoRun" = "off";
    "jest.showCoverageOnLoad" = false;
    "jest.runMode" = "on-demand";
  };
}
