{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.dbaeumer.vscode-eslint
    pkgs.vscode-marketplace.esbenp.prettier-vscode
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
  };
}
