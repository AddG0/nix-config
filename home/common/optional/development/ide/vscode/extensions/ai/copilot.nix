{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.github.copilot
    pkgs.vscode-marketplace.github.copilot-chat
  ];
  userSettings = {
    "github.copilot.enable" = {
      "*" = true;
      "plaintext" = false;
      "markdown" = true;
      "scminput" = false;
    };
    "github.copilot.editor.enableAutoCompletions" = true;
  };
}
