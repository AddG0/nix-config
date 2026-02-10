{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.ms-python.python
    pkgs.vscode-marketplace.ms-python.vscode-pylance
    pkgs.vscode-marketplace.ms-python.debugpy
    pkgs.vscode-marketplace-release.charliermarsh.ruff
  ];
  userSettings = {
    "python.languageServer" = "Pylance";
    "python.analysis.typeCheckingMode" = "basic";
    "python.analysis.autoImportCompletions" = true;
    "python.analysis.inlayHints.functionReturnTypes" = true;
    "python.analysis.inlayHints.variableTypes" = true;
    "python.poetryPath" = "${pkgs.stable.poetry}/bin/poetry";

    # Pytest testing
    "python.testing.pytestEnabled" = true;
    "python.testing.unittestEnabled" = false;
    "python.testing.pytestArgs" = ["-v"];

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

    # Hide Python cache/build directories from explorer
    "files.exclude" = {
      "**/__pycache__" = true;
      "**/.venv" = true;
      "**/venv" = true;
      "**/.pytest_cache" = true;
      "**/.mypy_cache" = true;
      "**/.ruff_cache" = true;
      "**/*.egg-info" = true;
      "**/.tox" = true;
      "**/.coverage" = true;
      "**/htmlcov" = true;
    };

    # Exclude from search
    "search.exclude" = {
      "**/__pycache__" = true;
      "**/.venv" = true;
      "**/venv" = true;
      "**/.pytest_cache" = true;
      "**/.mypy_cache" = true;
      "**/.ruff_cache" = true;
      "**/*.egg-info" = true;
      "**/.tox" = true;
      "**/.coverage" = true;
      "**/htmlcov" = true;
    };
  };
}
