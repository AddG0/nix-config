{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.continue.continue
  ];
  userSettings = {
    "continue.enableTabAutocomplete" = true;
  };
}
