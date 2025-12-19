{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.ms-vscode.hexeditor
  ];
  userSettings = {
    "hexeditor.columnWidth" = 16;
    "hexeditor.showDecodedText" = true;
  };
}
