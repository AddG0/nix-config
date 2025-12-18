{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.mechatroner.rainbow-csv
  ];
  userSettings = {
    "rainbow_csv.enable_tooltip" = true;
    "rainbow_csv.enable_auto_csv_lint" = true;
  };
}
