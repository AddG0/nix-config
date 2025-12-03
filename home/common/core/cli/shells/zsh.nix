{pkgs, ...}: let
  profile-zsh = pkgs.writeShellScriptBin "profile-zsh" ''
    zsh -c 'zmodload zsh/zprof; source ~/.zshrc; zprof' 2>/dev/null | head -40
  '';
in {
  programs.zsh = {
    enable = true;
    shellAliases = {
      urldecode = "${pkgs.python3Packages.urllib3}/bin/urllib3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
      urlencode = "${pkgs.python3Packages.urllib3}/bin/urllib3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
    };

    plugins = [
      # {
      #   name = "vi-mode";
      #   src = pkgs.zsh-vi-mode;
      #   file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      # }
    ];

    oh-my-zsh = {
      enable = true;
      theme = "agnoster";
      plugins = [
        "last-working-dir"
        "sudo"
      ];
    };

    enableCompletion = true;

    # Only rebuild completion cache once per day
    completionInit = ''
      autoload -Uz compinit
      if [[ -f ~/.zcompdump && $(date +'%Y%m%d') == $(date -r ~/.zcompdump +'%Y%m%d' 2>/dev/null || stat -c '%y' ~/.zcompdump 2>/dev/null | cut -d' ' -f1 | tr -d '-') ]]; then
        compinit -C
      else
        compinit
      fi
    '';
    syntaxHighlighting = {
      enable = true;
      highlighters = [
        "brackets"
      ];
      styles = {
        comment = "fg=black,bold";
      };
    };
    autosuggestion = {
      enable = true;
    };

    initContent = ''
      _fzf_comprun() {
          local command=$1
          shift

          case "$command" in
          cd) fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
          export|unset) fzf --preview "eval 'echo \$' {}" "$@" ;;
          ssh) fzf --preview 'dig {}' "$@" ;;
          *) fzf --preview "'bat -n --color=always --style=numbers --line-range=:500 {}'" "$@" ;;
          esac
      }

      _fzf_compgen_path() {
          fd --hidden --exclude ".git" . "$1"
      }

      _fzf_compgen_dir() {
          fd --type d --hidden --exclude ".git" . "$1"
      }

      function toggle_internet_checker() {
          # Attempt to enable the internet checker and capture the output
          output=$(launchctl load ~/Library/LaunchAgents/com.addg0.checkinternet.plist 2>&1)

          # Check if the load command was successful or if it failed with a specific error
          if echo "$output" | grep -q "Load failed: 5: Input/output error"; then
              launchctl unload ~/Library/LaunchAgents/com.addg0.checkinternet.plist 2>/dev/null
              echo "Internet checks are now disabled."
          else
              echo "Internet checks are now enabled."
          fi
      }

      # Check if kiro-cli is installed and disable autosuggestions if it is
      if [[ -f "''${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]]; then
        ZSH_AUTOSUGGEST_DISABLE="true"
        source "''${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
      fi

      # Load gdcloud completion for current session
      if command -v gdcloud >/dev/null 2>&1; then
        source <(gdcloud completion zsh)
        compdef _gdcloud gdcloud
      fi

      # Load local zshrc if it exists
      if [[ -f ~/.zshrc.imperitive ]]; then
        source ~/.zshrc.imperitive
      fi
    '';
  };

  home.packages = [
    profile-zsh
  ];
}
