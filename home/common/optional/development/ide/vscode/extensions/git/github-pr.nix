{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.github.vscode-pull-request-github
  ];
  userSettings = {
    "githubPullRequests.pullBranch" = "never";
    "githubPullRequests.fileListLayout" = "tree";
  };
}
