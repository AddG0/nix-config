{
  pkgs,
  config,
  ...
}: let
  inherit (config.hostSpec) handle;
  publicGitEmail = config.hostSpec.githubEmail;
in {
  programs.git = {
    enable = true;
    # package = pkgs.gitAndTools.gitFull;
    lfs.enable = true;

    settings = {
      user = {
        name = handle;
        email = publicGitEmail;
      };

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

      alias = {
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

    ignores = [
      ".csvignore"
      ".direnv"
      "result"
    ];
  };

  home.packages = with pkgs;
    lib.optionals (config.hostSpec.hostType != "server") [
      lazygit # Git terminal UI.
      renovate # Dependency update tool.
      gitkraken # Git GUI.
      devcontainer # Dev Container CLI.
      github-cli # GitHub CLI.
    ];

  programs.difftastic = {
    enable = true;
    git.enable = true;
    options = {
      background = "dark"; # matches catppuccin-mocha
      display = "side-by-side";
    };
  };

  programs.zsh.oh-my-zsh.plugins = [
    "git-auto-fetch"
    "github"
    "gitignore"
    "gh"
  ];

  # Git aliases - available across all shells
  home.shellAliases = {
    # Basic git shortcuts
    g = "git";
    ga = "git add";
    gaa = "git add --all";
    gapa = "git add --patch";
    gau = "git add --update";
    gav = "git add --verbose";

    # Git am (apply mailbox)
    gam = "git am";
    gama = "git am --abort";
    gamc = "git am --continue";
    gamscp = "git am --show-current-patch";
    gams = "git am --skip";
    gap = "git apply";
    gapt = "git apply --3way";

    # Git bisect
    gbs = "git bisect";
    gbsb = "git bisect bad";
    gbsg = "git bisect good";
    gbsn = "git bisect new";
    gbso = "git bisect old";
    gbsr = "git bisect reset";
    gbss = "git bisect start";

    # Git branch
    gbl = "git blame -w";
    gb = "git branch";
    gba = "git branch --all";
    gbd = "git branch --delete";
    gbD = "git branch --delete --force";
    gbm = "git branch --move";
    gbnm = "git branch --no-merged";
    gbr = "git branch --remote";

    # Git checkout
    gco = "git checkout";
    gcor = "git checkout --recurse-submodules";
    gcb = "git checkout -b";
    gcB = "git checkout -B";

    # Git cherry-pick
    gcp = "git cherry-pick";
    gcpa = "git cherry-pick --abort";
    gcpc = "git cherry-pick --continue";

    # Git clean & clone
    gclean = "git clean --interactive -d";
    gcl = "git clone --recurse-submodules";
    gclf = "git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules";

    # Git commit
    gcam = "git commit --all --message";
    gcas = "git commit --all --signoff";
    gcasm = "git commit --all --signoff --message";
    gcs = "git commit --gpg-sign";
    gcss = "git commit --gpg-sign --signoff";
    gcssm = "git commit --gpg-sign --signoff --message";
    gcmsg = "git commit --message";
    gcsm = "git commit --signoff --message";
    gc = "git commit --verbose";
    gca = "git commit --verbose --all";
    gcn = "git commit --verbose --no-edit";
    gcf = "git config --list";
    gcfu = "git commit --fixup";

    # Git diff
    gd = "git diff";
    gdca = "git diff --cached";
    gdcw = "git diff --cached --word-diff";
    gds = "git diff --staged";
    gdw = "git diff --word-diff";
    gdup = "git diff @{upstream}";
    gdt = "git diff-tree --no-commit-id --name-only -r";

    # Git fetch
    gf = "git fetch";
    gfa = "git fetch --all --tags --prune --jobs=10";
    gfo = "git fetch origin";

    # Git GUI
    gg = "git gui citool";
    gga = "git gui citool --amend";
    ghh = "git help";

    # Git log
    glgg = "git log --graph";
    glgga = "git log --graph --decorate --all";
    glgm = "git log --graph --max-count=10";
    glods = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset' --date=short";
    glod = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'";
    glola = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --all";
    glols = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --stat";
    glol = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'";
    glo = "git log --oneline --decorate";
    glog = "git log --oneline --decorate --graph";
    gloga = "git log --oneline --decorate --graph --all";
    glg = "git log --stat";
    glgp = "git log --stat --patch";

    # Git ls-files
    gignored = "git ls-files -v | grep '^[[:lower:]]'";
    gfg = "git ls-files | grep";

    # Git merge
    gm = "git merge";
    gma = "git merge --abort";
    gmc = "git merge --continue";
    gms = "git merge --squash";
    gmff = "git merge --ff-only";
    gmtl = "git mergetool --no-prompt";
    gmtlvim = "git mergetool --no-prompt --tool=vimdiff";

    # Git pull
    gl = "git pull";
    gpr = "git pull --rebase";
    gprv = "git pull --rebase -v";
    gpra = "git pull --rebase --autostash";
    gprav = "git pull --rebase --autostash -v";
    ggpur = "ggu";

    # Git push
    gp = "git push";
    gpd = "git push --dry-run";
    gpf = "git push --force-with-lease";
    gpv = "git push --verbose";
    gpod = "git push origin --delete";
    gpu = "git push upstream";

    # Git rebase
    grb = "git rebase";
    grba = "git rebase --abort";
    grbc = "git rebase --continue";
    grbi = "git rebase --interactive";
    grbo = "git rebase --onto";
    grbs = "git rebase --skip";
    grf = "git reflog";

    # Git remote
    gr = "git remote";
    grv = "git remote --verbose";
    gra = "git remote add";
    grrm = "git remote remove";
    grmv = "git remote rename";
    grset = "git remote set-url";
    grup = "git remote update";

    # Git reset
    grh = "git reset";
    gru = "git reset --";
    grhh = "git reset --hard";
    grhk = "git reset --keep";
    grhs = "git reset --soft";

    # Git restore
    grs = "git restore";
    grss = "git restore --source";
    grst = "git restore --staged";

    # Git revert
    grev = "git revert";
    greva = "git revert --abort";
    grevc = "git revert --continue";

    # Git rm
    grm = "git rm";
    grmc = "git rm --cached";

    # Git show
    gcount = "git shortlog --summary --numbered";
    gsh = "git show";
    gsps = "git show --pretty=short --show-signature";

    # Git stash
    gstall = "git stash --all";
    gstaa = "git stash apply";
    gstc = "git stash clear";
    gstd = "git stash drop";
    gstl = "git stash list";
    gstp = "git stash pop";
    gsta = "git stash push";
    gsts = "git stash show --patch";
    gstu = "gsta --include-untracked";

    # Git status
    gst = "git status";
    gss = "git status --short";
    gsb = "git status --short --branch";

    # Git submodule
    gsi = "git submodule init";
    gsu = "git submodule update";

    # Git svn
    gsd = "git svn dcommit";
    gsr = "git svn rebase";

    # Git switch
    gsw = "git switch";
    gswc = "git switch --create";

    # Git tag
    gta = "git tag --annotate";
    gts = "git tag --sign";
    gtv = "git tag | sort -V";

    # Git update-index
    gignore = "git update-index --assume-unchanged";
    gunignore = "git update-index --no-assume-unchanged";

    # Git whatchanged & worktree
    gwch = "git whatchanged -p --abbrev-commit --pretty=medium";
    gwt = "git worktree";
    gwta = "git worktree add";
    gwtls = "git worktree list";
    gwtmv = "git worktree move";
    gwtrm = "git worktree remove";
  };

  # Git zsh functions - these cannot be shell aliases as they require zsh-specific features
  programs.zsh.initContent = ''
    # Git version checking
    autoload -Uz is-at-least
    git_version="''${''${(As: :)$(git version 2>/dev/null)}[3]}"

    #
    # Git Helper Functions
    #

    # The name of the current branch
    function current_branch() {
      git_current_branch
    }

    # Check for develop and similarly named branches
    function git_develop_branch() {
      command git rev-parse --git-dir &>/dev/null || return
      local branch
      for branch in dev devel develop development; do
        if command git show-ref -q --verify refs/heads/$branch; then
          echo $branch
          return 0
        fi
      done
      echo develop
      return 1
    }

    # Check if main exists and use instead of master
    function git_main_branch() {
      command git rev-parse --git-dir &>/dev/null || return
      local ref
      for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,stable,master}; do
        if command git show-ref -q --verify $ref; then
          echo ${"ref:t"}
          return 0
        fi
      done
      echo master
      return 1
    }

    # Rename git branch locally and remotely
    function grename() {
      if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: $0 old_branch new_branch"
        return 1
      fi
      git branch -m "$1" "$2"
      if git push origin :"$1"; then
        git push --set-upstream origin "$2"
      fi
    }

    # Recursively unwip all recent --wip-- commits
    function gunwipall() {
      local _commit=$(git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H)
      if [[ "$_commit" != "$(git rev-parse HEAD)" ]]; then
        git reset $_commit || return 1
      fi
    }

    # Warn if the current branch is a WIP
    function work_in_progress() {
      command git -c log.showSignature=false log -n 1 2>/dev/null | grep -q -- "--wip--" && echo "WIP!!"
    }

    # Git root - cd to repo root
    alias grt='cd "$(git rev-parse --show-toplevel || echo .)"'

    # WIP - Work in progress commit (zsh/bash only - uses 2> redirection)
    alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'

    # Pull and push in one command
    function ggpnp() {
      if [[ "$#" == 0 ]]; then
        ggl && ggp
      else
        ggl "''${*}" && ggp "''${*}"
      fi
    }
    compdef _git ggpnp=git-checkout

    # Delete all merged branches
    function gbda() {
      git branch --no-color --merged | command grep -vE "^([+*]|\s*($(git_main_branch)|$(git_develop_branch))\s*$)" | command xargs git branch --delete 2>/dev/null
    }

    # Delete squash-merged branches
    function gbds() {
      local default_branch=$(git_main_branch)
      (( ! $? )) || default_branch=$(git_develop_branch)
      git for-each-ref refs/heads/ "--format=%(refname:short)" | \
        while read branch; do
          local merge_base=$(git merge-base $default_branch $branch)
          if [[ $(git cherry $default_branch $(git commit-tree $(git rev-parse $branch\^{tree}) -p $merge_base -m _)) = -* ]]; then
            git branch -D $branch
          fi
        done
    }

    # Delete local branches that are gone on remote
    alias gbgd='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '"'"'{print $1}'"'"' | xargs git branch -d'
    alias gbgD='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '"'"'{print $1}'"'"' | xargs git branch -D'
    alias ggsup='git branch --set-upstream-to=origin/$(git_current_branch)'
    alias gbg='LANG=C git branch -vv | grep ": gone\]"'

    # Checkout branch shortcuts using git_develop_branch and git_main_branch
    alias gcd='git checkout $(git_develop_branch)'
    alias gcm='git checkout $(git_main_branch)'

    # Clone and cd into the directory
    function gccd() {
      setopt localoptions extendedglob
      local repo="''${''${@[(r)(ssh://*|git://*|ftp(s)#://*|http(s)#://*|*@*)(.git/#)#]}:-$_}"
      command git clone --recurse-submodules "$@" || return
      [[ -d "$_" ]] && cd "$_" || cd "''${''${repo:t}%.git/#}"
    }
    compdef _git gccd=git-clone

    # View diff with vim
    function gdv() { git diff -w "$@" | view - }
    compdef _git gdv=git-diff

    # Diff without lock files
    function gdnolock() {
      git diff "$@" ":(exclude)package-lock.json" ":(exclude)*.lock"
    }
    compdef _git gdnolock=git-diff

    # Pretty log function
    function _git_log_prettily() {
      if ! [ -z $1 ]; then
        git log --pretty=$1
      fi
    }
    compdef _git _git_log_prettily=git-log
    alias glp='_git_log_prettily'

    # Merge origin/main or upstream/main
    alias gmom='git merge origin/$(git_main_branch)'
    alias gmum='git merge upstream/$(git_main_branch)'

    # Pull with rebase from current branch
    function ggu() {
      [[ "$#" != 1 ]] && local b="$(git_current_branch)"
      git pull --rebase origin "''${b:=$1}"
    }
    compdef _git ggu=git-checkout

    # Pull from origin with shortcuts
    alias gprom='git pull --rebase origin $(git_main_branch)'
    alias gpromi='git pull --rebase=interactive origin $(git_main_branch)'
    alias gprum='git pull --rebase upstream $(git_main_branch)'
    alias gprumi='git pull --rebase=interactive upstream $(git_main_branch)'
    alias ggpull='git pull origin "$(git_current_branch)"'

    function ggl() {
      if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]; then
        git pull origin "''${*}"
      else
        [[ "$#" == 0 ]] && local b="$(git_current_branch)"
        git pull origin "''${b:=$1}"
      fi
    }
    compdef _git ggl=git-checkout

    # Pull from upstream shortcuts
    alias gluc='git pull upstream $(git_current_branch)'
    alias glum='git pull upstream $(git_main_branch)'

    # Force push to origin
    function ggf() {
      [[ "$#" != 1 ]] && local b="$(git_current_branch)"
      git push --force origin "''${b:=$1}"
    }
    compdef _git ggf=git-checkout

    # Force push with lease
    function ggfl() {
      [[ "$#" != 1 ]] && local b="$(git_current_branch)"
      git push --force-with-lease origin "''${b:=$1}"
    }
    compdef _git ggfl=git-checkout

    # Push shortcuts
    alias gpsup='git push --set-upstream origin $(git_current_branch)'
    is-at-least 2.30 "$git_version" \
      && alias gpsupf='git push --set-upstream origin $(git_current_branch) --force-with-lease --force-if-includes' \
      || alias gpsupf='git push --set-upstream origin $(git_current_branch) --force-with-lease'
    alias ggpush='git push origin "$(git_current_branch)"'

    function ggp() {
      if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]; then
        git push origin "''${*}"
      else
        [[ "$#" == 0 ]] && local b="$(git_current_branch)"
        git push origin "''${b:=$1}"
      fi
    }
    compdef _git ggp=git-checkout

    # Rebase shortcuts using helper functions
    alias grbd='git rebase $(git_develop_branch)'
    alias grbm='git rebase $(git_main_branch)'
    alias grbom='git rebase origin/$(git_main_branch)'
    alias grbum='git rebase upstream/$(git_main_branch)'

    # Reset to origin branch
    alias groh='git reset origin/$(git_current_branch) --hard'

    # Unwip - undo --wip-- commit (zsh/bash only - uses && and grep)
    alias gunwip='git rev-list --max-count=1 --format="%s" HEAD | grep -q "\--wip--" && git reset HEAD~1'

    # Git SVN (zsh/bash only - uses && and git_main_branch function)
    alias git-svn-dcommit-push='git svn dcommit && git push github $(git_main_branch):svntrunk'

    # Git describe tags (zsh/bash only - uses command substitution)
    alias gdct='git describe --tags $(git rev-list --tags --max-count=1)'

    # Commit aliases with ! (zsh/bash only - Nushell doesn't support ! in alias names)
    alias gca!='git commit --verbose --all --amend'
    alias gcan!='git commit --verbose --all --no-edit --amend'
    alias gcans!='git commit --verbose --all --signoff --no-edit --amend'
    alias gcann!='git commit --verbose --all --date=now --no-edit --amend'
    alias gc!='git commit --verbose --amend'
    alias gcn!='git commit --verbose --no-edit --amend'

    # Push force alias with ! (zsh/bash only - Nushell doesn't support ! in alias names)
    alias gpf!='git push --force'

    # Aliases with ; command chaining (zsh/bash only - Nushell executes ; at config level, not in alias)
    alias gpoat='git push origin --all && git push origin --tags'
    alias gpristine='git reset --hard && git clean --force -dfx'
    alias gwipe='git reset --hard && git clean --force -df'

    # Switch to develop/main branch
    alias gswd='git switch $(git_develop_branch)'
    alias gswm='git switch $(git_main_branch)'

    # Git tag listing
    alias gtl='gtl(){ git tag --sort=-v:refname -n --list "''${1}*" }; noglob gtl'

    # Gitk
    alias gke='\gitk --all $(git log --walk-reflogs --pretty=%h) &!'

    unset git_version

    # Deprecated alias warnings
    local old_alias new_alias
    for old_alias new_alias (
      gup     gpr
      gupv    gprv
      gupa    gpra
      gupav   gprav
      gupom   gprom
      gupomi  gpromi
    ); do
      aliases[$old_alias]="
        print -Pu2 \"%F{yellow}[oh-my-zsh] '%F{red}''${old_alias}%F{yellow}' is a deprecated alias, using '%F{green}''${new_alias}%F{yellow}' instead.%f\"
        $new_alias"
    done
    unset old_alias new_alias
  '';
}
