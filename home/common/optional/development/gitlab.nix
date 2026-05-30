{pkgs, ...}: {
  home.packages = [pkgs.glab];

  # Alias to quickly switch accounts
  home.shellAliases.glab-login = "glab auth login --hostname gitlab.com --git-protocol ssh --api-protocol https";
}
