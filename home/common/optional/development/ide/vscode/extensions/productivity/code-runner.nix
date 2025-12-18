{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.formulahendry.code-runner
  ];
  userSettings = {
    "code-runner.runInTerminal" = true;
    "code-runner.saveFileBeforeRun" = true;
    "code-runner.clearPreviousOutput" = true;
    "code-runner.showExecutionMessage" = false;
  };
}
