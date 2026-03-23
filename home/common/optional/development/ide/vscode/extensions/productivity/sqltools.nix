{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.mtxr.sqltools
    pkgs.vscode-marketplace.mtxr.sqltools-driver-pg
    pkgs.vscode-marketplace.mtxr.sqltools-driver-mysql
    pkgs.vscode-marketplace.mtxr.sqltools-driver-sqlite
    pkgs.vscode-marketplace-release.khanghua.sqltools-dynamodb-driver
  ];

  # SQLTools resolves sqlite3 from ~/.local/share/vscode-sqltools/node_modules
  home.file.".local/share/vscode-sqltools/node_modules/sqlite3".source = "${pkgs.node-sqlite3}/lib/node_modules/sqlite3";

  userSettings = {
    "sqltools.useNodeRuntime" = "${pkgs.nodejs}/bin/node";
    "sqltools.autoOpenSessionFiles" = false;
    "sqltools.results.location" = "current";
  };
}
