{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace-release.ms-vscode.hexeditor
  ];
  userSettings = {
    "hexeditor.columnWidth" = 16;
    "hexeditor.showDecodedText" = true;
  };
}
