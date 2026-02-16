{
  pkgs,
  config,
  ...
}: {
  extensions = [
    pkgs.vscode-marketplace.leetcode.vscode-leetcode
  ];
  userSettings = {
    "leetcode.workspaceFolder" = "${config.home.homeDirectory}/.leetcode";
  };
}
