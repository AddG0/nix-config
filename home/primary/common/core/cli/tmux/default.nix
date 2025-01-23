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
      tmux-fzf
      # {
      #   plugin = catppuccin;
      #   extraConfig = ''
      #     set -g @catppuccin_window_left_separator ""
      #     set -g @catppuccin_window_right_separator " "
      #     set -g @catppuccin_window_middle_separator " █"
      #     set -g @catppuccin_window_number_position "right"
      #     set -g @catppuccin_window_default_fill "number"
      #     set -g @catppuccin_window_default_text "#W"
      #     set -g @catppuccin_window_current_fill "number"
      #     set -g @catppuccin_window_current_text "#W#{?window_zoomed_flag,(),}"
      #     set -g @catppuccin_status_modules_right "directory date_time"
      #     set -g @catppuccin_status_modules_left "session"
      #     set -g @catppuccin_status_left_separator  " "
      #     set -g @catppuccin_status_right_separator " "
      #     set -g @catppuccin_status_right_separator_inverse "no"
      #     set -g @catppuccin_status_fill "icon"
      #     set -g @catppuccin_status_connect_separator "no"
      #     set -g @catppuccin_directory_text "#{b:pane_current_path}"
      #     set -g @catppuccin_meetings_text "#($HOME/.config/tmux/scripts/cal.sh)"
      #     set -g @catppuccin_date_time_text "%H:%M"
      #   '';
      # }
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
      set -g @plugin 'wfxr/tmux-fzf-url'
      set -g @plugin 'omerxx/catppuccin-tmux' # My fork that holds the meetings script bc I'm lazy af
      set -g @plugin 'omerxx/tmux-sessionx'
      set -g @plugin 'omerxx/tmux-floax'
      set -g @plugin 'tmux-plugins/tpm'

      set -g @catppuccin_window_left_separator ""
      set -g @catppuccin_window_right_separator " "
      set -g @catppuccin_window_middle_separator " █"
      set -g @catppuccin_window_number_position "right"
      set -g @catppuccin_window_default_fill "number"
      set -g @catppuccin_window_default_text "#W"
      set -g @catppuccin_window_current_fill "number"
      set -g @catppuccin_window_current_text "#W#{?window_zoomed_flag,(),}"
      set -g @catppuccin_status_modules_right "directory date_time"
      set -g @catppuccin_status_modules_left "session"
      set -g @catppuccin_status_left_separator  " "
      set -g @catppuccin_status_right_separator " "
      set -g @catppuccin_status_right_separator_inverse "no"
      set -g @catppuccin_status_fill "icon"
      set -g @catppuccin_status_connect_separator "no"
      set -g @catppuccin_directory_text "#{b:pane_current_path}"
      set -g @catppuccin_meetings_text "#($HOME/.config/tmux/scripts/cal.sh)"
      set -g @catppuccin_date_time_text "%H:%M"

      set -g @floax-width '80%'
      set -g @floax-height '80%'
      set -g @floax-border-color 'magenta'
      set -g @floax-text-color 'blue'
      set -g @floax-bind 'p'
      set -g @floax-change-path 'true'

      set -g @sessionx-bind-zo-new-window 'ctrl-y'
      set -g @sessionx-auto-accept 'off'
      set -g @sessionx-custom-paths '/Users/omerxx/dotfiles'
      set -g @sessionx-bind 'o'
      set -g @sessionx-x-path '~/dotfiles'
      set -g @sessionx-window-height '85%'
      set -g @sessionx-window-width '75%'
      set -g @sessionx-zoxide-mode 'on'
      set -g @sessionx-custom-paths-subdirectories 'false'
      set -g @sessionx-filter-current 'false'

      set-window-option -g mode-keys vi

      set -g prefix ^A
      set -g base-index 1              # start indexing windows at 1 instead of 0
      set -g detach-on-destroy off     # don't exit from tmux when closing a session
      set -g escape-time 0             # zero-out escape time delay
      set -g history-limit 1000000     # increase history size (from 2,000)
      set -g renumber-windows on       # renumber all windows when any window is closed
      set -g set-clipboard on          # use system clipboard
      set -g status-position top       # macOS / darwin style

      set -g pane-active-border-style 'fg=magenta,bg=default'
      set -g pane-border-style 'fg=brightblack,bg=default'

      set -g @fzf-url-fzf-options '-p 60%,30% --prompt="   " --border-label=" Open URL "'
      set -g @fzf-url-history-limit '2000'

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

      run '~/.tmux/plugins/tpm/tpm'
    '';
  };
  home.shellAliases = shellAliases;
  programs.zsh.initExtra = ''
    function default_tmux_session() {
        if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
            tmux attach-session -t default 2>/dev/null || tmux new-session -s default -c "$PWD"
        fi
    }
  '';
}
