{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.mtxr.sqltools
    pkgs.vscode-marketplace.mtxr.sqltools-driver-pg
    pkgs.vscode-marketplace.mtxr.sqltools-driver-mysql
    pkgs.vscode-marketplace.mtxr.sqltools-driver-sqlite
    pkgs.vscode-marketplace-release.khanghua.sqltools-dynamodb-driver
  ];
  userSettings = {
    "sqltools.useNodeRuntime" = false;
    "sqltools.autoOpenSessionFiles" = false;
    "sqltools.results.location" = "current";
  };
}
