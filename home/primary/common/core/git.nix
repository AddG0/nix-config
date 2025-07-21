{
  pkgs,
  lib,
  config,
  hostSpec,
  ...
}: let
  handle = hostSpec.handle;
  publicGitEmail = hostSpec.githubEmail;
  username = hostSpec.username;
in {
  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;
    lfs.enable = true;
    userName = handle;
    userEmail = publicGitEmail;

    includes = [
      {
        # use different email & name for work
        path = "${config.home.homeDirectory}/home/ShipperHQ/.gitconfig";
        condition = "gitdir:${config.home.homeDirectory}/home/ShipperHQ/**";
      }
    ];

    extraConfig = {
      log.showSignature = "true";
      trim.bases = "develop,master,main"; # for git-trim
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = "true";
      core.pager = "bat --paging=always --plain";
      url = {
        "ssh://git@github.com" = {
          insteadOf = "https://github.com";
        };
        "ssh://git@gitlab.com" = {
          insteadOf = "https://gitlab.com";
        };
      };

      gpg.format = "ssh";
    };

    ignores = [
      ".csvignore"
      ".direnv"
      "result"
    ];

    aliases = {
      # common aliases
      br = "branch";
      co = "checkout";
      st = "status";
      ls = "log --pretty=format:\"%C(yellow)%h%Cred%d\\\\ %Creset%s%Cblue\\\\ [%cn]\" --decorate";
      ll = "log --pretty=format:\"%C(yellow)%h%Cred%d\\\\ %Creset%s%Cblue\\\\ [%cn]\" --decorate --numstat";
      cm = "commit -m"; # commit via `git cm <message>`
      ca = "commit -am"; # commit all changes via `git ca <message>`
      dc = "diff --cached";

      amend = "commit --amend -m"; # amend commit message via `git amend <message>`
      unstage = "reset HEAD --"; # unstage file via `git unstage <file>`
      merged = "branch --merged"; # list merged(into HEAD) branches via `git merged`
      unmerged = "branch --no-merged"; # list unmerged(into HEAD) branches via `git unmerged`
      nonexist = "remote prune origin --dry-run"; # list non-exist(remote) branches via `git nonexist`

      # delete merged branches except master & dev & staging
      #  `!` indicates it's a shell script, not a git subcommand
      delmerged = ''! git branch --merged | egrep -v "(^\*|main|master|dev|staging)" | xargs git branch -d'';
      # delete non-exist(remote) branches
      delnonexist = "remote prune origin";

      # aliases for submodule
      update = "submodule update --init --recursive";
      foreach = "submodule foreach";
    };
  };

  home.packages = with pkgs; [
    lazygit # Git terminal UI.
    github-cli # GitHub CLI.
    stable.renovate # Dependency update tool.
    devcontainer # Dev Container CLI.
    gitkraken # Git GUI.
  ];

  programs.zsh.oh-my-zsh.plugins = [
    "git"
    "git-auto-fetch"
    "github"
    "gitignore"
    "gh"
  ];
}
