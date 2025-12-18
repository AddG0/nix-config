{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.wix.vscode-import-cost
  ];
  userSettings = {
    "importCost.showCalculatingDecoration" = true;
    "importCost.smallPackageSize" = 50;
    "importCost.mediumPackageSize" = 100;
  };
}
