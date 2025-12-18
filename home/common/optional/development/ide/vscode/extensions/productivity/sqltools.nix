{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.mtxr.sqltools
    pkgs.vscode-marketplace.mtxr.sqltools-driver-pg
    pkgs.vscode-marketplace.mtxr.sqltools-driver-mysql
    pkgs.vscode-marketplace.mtxr.sqltools-driver-sqlite
  ];
  userSettings = {
    "sqltools.useNodeRuntime" = false;
    "sqltools.autoOpenSessionFiles" = false;
    "sqltools.results.location" = "current";
  };
}
