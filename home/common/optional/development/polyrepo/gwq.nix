{
  config,
  pkgs,
  ...
}: let
  gwadd-script = pkgs.writeShellApplication {
    name = "gwadd";
    runtimeInputs = with pkgs; [git gwq gawk sesh tmux];
    text = builtins.readFile ./scripts/gwadd.sh;
  };

  gwadd-zsh-completion = pkgs.writeTextFile {
    name = "gwadd-zsh-completion";
    destination = "/share/zsh/site-functions/_gwadd";
    text = builtins.readFile ./scripts/gwadd-completion.zsh;
  };

  gwadd = pkgs.symlinkJoin {
    name = "gwadd";
    paths = [gwadd-script gwadd-zsh-completion];
  };
in {
  home.packages = [pkgs.gwq gwadd];

  # Worktrees live next to clones, with `--<branch>` suffix for disambiguation.
  # e.g. ~/Projects/code/.../ai-eng-framework clone →
  #      ~/Projects/code/.../ai-eng-framework--ENG-123 worktree
  #
  # `--` separator (not `=`) avoids the `-javaagent:<path>=<args>` collision
  # that breaks JaCoCo in Gradle/Maven test runs.
  #
  # The template here is gwq's fallback; `gwadd` is the preferred entrypoint
  # because gwq's URL parser drops GitLab subgroups (d-kuro/gwq#85, partially
  # fixed in PR #87) and gets fooled by insteadOf URL rewrites. The wrapper
  # passes an explicit path so neither comes into play.
  xdg.configFile."gwq/config.toml".text = ''
    [worktree]
    basedir = "${config.polyrepo.ghqRoot}"

    [naming]
    template = "{{.Host}}/{{.Owner}}/{{.Repository}}--{{.Branch}}"
  '';

  # Alt-W: create/enter a gwq worktree for the current repo (worktree-side Alt-G).
  # Dispatches via BUFFER+accept-line, not a direct call, so gwadd's create prompt
  # and its `sesh connect` handoff run in the foreground shell.
  programs.zsh.initContent = ''
    gwq-add-fzf-widget() {
      git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        zle -M "gwadd: not inside a git repo"
        return
      }
      local out query match branch
      out=$({
        git for-each-ref --format='%(refname:short)' refs/heads
        git for-each-ref --format='%(refname:lstrip=3)' refs/remotes
      } 2>/dev/null | grep -vx HEAD | sort -u | fzf \
        --height 40% --reverse --border --print-query \
        --prompt 'worktree branch> ' \
        --header 'enter: existing branch · type a new name to create' \
        --preview 'git log --oneline --color=always -n 20 {} 2>/dev/null || git log --oneline --color=always -n 20 origin/{} 2>/dev/null || echo "(new branch — will be created)"') || return
      query=$(head -1 <<<"$out")
      match=$(sed -n 2p <<<"$out")
      branch=''${match:-$query}
      [[ -z "$branch" ]] && return
      BUFFER="gwadd ''${(q)branch}"
      zle accept-line
    }
    zle -N gwq-add-fzf-widget
    bindkey '^[w' gwq-add-fzf-widget
  '';
}
