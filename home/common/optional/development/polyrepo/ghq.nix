{
  config,
  lib,
  pkgs,
  ...
}: let
  ghq-gitlab-group = pkgs.writeShellApplication {
    name = "ghq-gitlab-group";
    runtimeInputs = with pkgs; [glab ghq jq git];
    text = builtins.readFile ./scripts/ghq-gitlab-group.sh;
  };

  # One long line per root: a multi-line Nix block interpolates with its own
  # indent baseline and lands crooked in the generated .zshrc.
  extraRootLines =
    lib.concatMapStringsSep "\n        " (
      extra: let
        levels = "-mindepth ${toString extra.depth} -maxdepth ${toString extra.depth}";
        display = ''"${extra.label}/''${checkout#${extra.path}/}"'';
      in "find ${lib.escapeShellArg extra.path} ${levels} -type d 2>/dev/null | while IFS= read -r checkout; do printf '%s\\t%s\\n' ${display} \"$checkout\"; done"
    )
    config.polyrepo.extraSearchRoots;
in {
  home.packages = [pkgs.ghq ghq-gitlab-group];

  programs.git.settings.ghq = {
    root = config.polyrepo.ghqRoot;
    # ghq auto-detects the VCS for non-github.com hosts via a go-import HTTP
    # probe that truncates GitLab *nested* subgroup paths to owner/repo (broke
    # in ghq PR #378 / v1.6.0). Pin gitlab.com to plain git so `ghq get`
    # preserves the full subgroup path. Matched via `git config --get-urlmatch`.
    "https://gitlab.com/".vcs = "git";
  };

  home.shellAliases = {
    ghql = "ghq list";
    ghqg = "ghq get";
    ghqu = "ghq get -u";
  };

  # Alt-G: fuzzy-jump to any ghq-managed repo, plus any polyrepo.extraSearchRoots.
  # Ctrl-G is reserved by fzf-git-sh for in-repo chords.
  #
  # Lines are "<display>\t<absolute path>", fzf matching the display only:
  # extra roots sit outside the ghq tree, so no single prefix rebuilds a path.
  programs.zsh.initContent = ''
    ghq-fzf-widget() {
      local root selection target
      root=$(ghq root)
      selection=$({
        ghq list -p | while IFS= read -r checkout; do
          printf '%s\t%s\n' "''${checkout#$root/}" "$checkout"
        done
        ${extraRootLines}
      } | fzf \
        --height 60% --reverse --border \
        --delimiter='\t' --with-nth=1 \
        --preview "eza --tree --color=always --level=2 --git-ignore {2} 2>/dev/null || ls {2}") || return
      [[ -z "$selection" ]] && return
      target=''${selection#*$'\t'}
      BUFFER="cd ''${(q)target}"
      zle accept-line
    }
    zle -N ghq-fzf-widget
    bindkey '^[g' ghq-fzf-widget
  '';
}
