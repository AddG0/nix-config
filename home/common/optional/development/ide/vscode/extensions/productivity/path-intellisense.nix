{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.christian-kohler.path-intellisense
  ];
  userSettings = {
    "path-intellisense.autoSlashAfterDirectory" = true;
    "path-intellisense.autoTriggerNextSuggestion" = true;
    "path-intellisense.extensionOnImport" = true;
  };
}
