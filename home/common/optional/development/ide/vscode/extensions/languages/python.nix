{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.ms-python.python
    pkgs.vscode-marketplace.ms-python.vscode-pylance
    pkgs.vscode-marketplace.ms-python.debugpy
  ];
  userSettings = {
    "python.languageServer" = "Pylance";
    "python.analysis.typeCheckingMode" = "basic";
    "python.analysis.autoImportCompletions" = true;
    "python.analysis.inlayHints.functionReturnTypes" = true;
    "python.analysis.inlayHints.variableTypes" = true;
  };
}
