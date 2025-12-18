{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.gitlab.gitlab-workflow
  ];
  userSettings = {
    # Hide GitLab Duo from sidebar
    "gitlab.duoChat.enabled" = false;
  };
}
