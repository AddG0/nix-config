{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.ms-python.python
    pkgs.vscode-marketplace.ms-python.vscode-pylance
    pkgs.vscode-marketplace.ms-python.debugpy
    pkgs.vscode-marketplace.charliermarsh.ruff
  ];
  userSettings = {
    "python.languageServer" = "Pylance";
    "python.analysis.typeCheckingMode" = "basic";
    "python.analysis.autoImportCompletions" = true;
    "python.analysis.inlayHints.functionReturnTypes" = true;
    "python.analysis.inlayHints.variableTypes" = true;

    # Ruff - fast Python linter and formatter
    "ruff.path" = ["${pkgs.ruff}/bin/ruff"];

    # Use Ruff as the default formatter for Python
    "[python]" = {
      "editor.defaultFormatter" = "charliermarsh.ruff";
      "editor.formatOnSave" = true;
      "editor.codeActionsOnSave" = {
        "source.organizeImports" = "explicit";
        "source.fixAll" = "explicit";
      };
    };
  };
}
