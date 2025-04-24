{
  config,
  pkgs,
  ...
}: let
  shellAliases = {
    "t" = "tmux";
    "td" = "default_tmux_session";
  };
in {
  programs.tmux = {
    enable = true;
    tmuxinator.enable = true;
    tmuxp.enable = true;
    mouse = true;
    clock24 = false;
    shell = "${config.home.homeDirectory}/.nix-profile/bin/zsh";
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
      better-mouse-mode
      yank
      tmux-thumbs
      {
        plugin = tmux-fzf;
        extraConfig = ''
          set -g @fzf-url-fzf-options '-p 60%,30% --prompt="   " --border-label=" Open URL "'
          set -g @fzf-url-history-limit '2000'
        '';
      }
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_window_left_separator ""
          set -g @catppuccin_window_right_separator " "
          set -g @catppuccin_window_middle_separator " █"
          set -g @catppuccin_window_number_position "right"

          set -g @catppuccin_status_modules_right "directory user host session"
          set -g @catppuccin_status_left_separator  " "
          set -g @catppuccin_status_right_separator ""
          set -g @catppuccin_status_right_separator_inverse "no"
          set -g @catppuccin_status_fill "icon"
          set -g @catppuccin_status_connect_separator "no"
          set -g @catppuccin_status_modules_right "application session date_time"

          # Set the window name to the current path if it is zsh, otherwise set it to the window name
          set -g @catppuccin_window_default_fill "number"
          set -g @catppuccin_window_default_text "#{?#{==:#{window_name},zsh},#{b:pane_current_path},#{?window_name,#{window_name},#{b:pane_current_path}}}"

          set -g @catppuccin_window_current_fill "number"
          set -g @catppuccin_window_current_text "#{?#{==:#{window_name},zsh},#{b:pane_current_path},#{?window_name,#{window_name},#{b:pane_current_path}}}"
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
        '';
      }
    ];
    extraConfig = ''
      set -g @floax-width '80%'
      set -g @floax-height '80%'
      set -g @floax-border-color 'magenta'
      set -g @floax-text-color 'blue'
      set -g @floax-bind 'p'
      set -g @floax-change-path 'true'

      set -g base-index 1              # start indexing windows at 1 instead of 0
      set -g detach-on-destroy off     # don't exit from tmux when closing a session
      set -g escape-time 0             # zero-out escape time delay
      set -g history-limit 1000000     # increase history size (from 2,000)
      set -g renumber-windows on       # renumber all windows when any window is closed
      set -g set-clipboard on          # use system clipboard
      set -g status-position top       # macOS / darwin style

      set -g status-bg default
      set -g status-style bg=default

      ${builtins.readFile ./binds.conf}

      # Vi copy mode with system clipboard support
      bind-key -T copy-mode-vi 'v' send -X begin-selection
      if-shell "uname | grep -q Darwin" {
        bind-key -T copy-mode-vi 'y' send -X copy-pipe-and-cancel 'reattach-to-user-namespace pbcopy'
        bind-key -T copy-mode-vi Enter send -X copy-pipe-and-cancel 'reattach-to-user-namespace pbcopy'
      } {
        bind-key -T copy-mode-vi 'y' send -X copy-pipe-and-cancel 'xclip -in -selection clipboard'
        bind-key -T copy-mode-vi Enter send -X copy-pipe-and-cancel 'xclip -in -selection clipboard'
      }
    '';
  };
  home.shellAliases = shellAliases;
  programs.zsh.initContent = ''
    function default_tmux_session() {
        if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
            tmux attach-session -t default 2>/dev/null || tmux new-session -s default -c "$PWD"
        fi
    }
  '';
}
