{pkgs, ...}: let
  ghq-gitlab-group = pkgs.writeShellApplication {
    name = "ghq-gitlab-group";
    runtimeInputs = with pkgs; [glab ghq jq findutils];
    text = builtins.readFile ./scripts/ghq-gitlab-group.sh;
  };
in {
  home.packages = [pkgs.ghq ghq-gitlab-group];

  # ~/Projects matches xdg-user-dirs 0.20 (April 2026) XDG_PROJECTS_DIR.
  # The code/ subdir keeps ghq's host-namespaced layout separate from
  # non-code projects (3d-printing, etc).
  programs.git.settings.ghq.root = "~/Projects/code";

  home.shellAliases = {
    ghql = "ghq list";
    ghqg = "ghq get";
    ghqu = "ghq get -u";
  };

  # Alt-G: fuzzy-jump to any ghq-managed repo.
  # Ctrl-G is reserved by fzf-git-sh for in-repo chords.
  programs.zsh.initContent = ''
    ghq-fzf-widget() {
      local root repo
      root=$(ghq root)
      repo=$(ghq list | fzf \
        --height 60% --reverse --border \
        --preview "eza --tree --color=always --level=2 --git-ignore $root/{} 2>/dev/null || ls $root/{}") || return
      [[ -z "$repo" ]] && return
      BUFFER="cd $root/$repo"
      zle accept-line
    }
    zle -N ghq-fzf-widget
    bindkey '^[g' ghq-fzf-widget
  '';
}
