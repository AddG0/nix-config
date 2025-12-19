{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.stylelint.vscode-stylelint
  ];
  userSettings = {
    "stylelint.validate" = ["css" "scss" "less" "postcss"];
    "css.validate" = false;
    "scss.validate" = false;
    "less.validate" = false;
  };
}
