{
  config,
  pkgs,
  ...
}: let
  isLaptop = config.hostSpec.hostType == "laptop";
  shellAliases = {
    "t" = "tmux";
    "mux" = "tmuxinator";
  };

  # Wrap tmux so a bare `tmux` (no args, outside a session) creates/attaches a
  # session named after the current folder. With args or inside $TMUX it
  # forwards verbatim, so every other caller is unaffected.
  tmuxLauncher = pkgs.writeShellScript "tmux" ''
    if [ -n "$TMUX" ] || [ "$#" -gt 0 ]; then
      exec ${pkgs.tmux}/bin/tmux "$@"
    fi
    name=$(${pkgs.coreutils}/bin/basename "$PWD" | ${pkgs.coreutils}/bin/tr '.: ' '___')
    exec ${pkgs.tmux}/bin/tmux new-session -A -s "$name"
  '';
  tmuxWrapped = pkgs.symlinkJoin {
    name = "tmux-folder-session";
    paths = [pkgs.tmux];
    postBuild = ''
      rm -f "$out/bin/tmux"
      ln -s ${tmuxLauncher} "$out/bin/tmux"
    '';
  };

  # On the last session, wipe the continuum/resurrect snapshot so a deliberate
  # exit starts fresh; a reboot with sessions still alive keeps it and restores.
  tmuxQuit = pkgs.writeShellScript "tmux-quit-session" ''
    tmux=${pkgs.tmux}/bin/tmux
    if [ "$("$tmux" list-sessions | ${pkgs.coreutils}/bin/wc -l)" -le 1 ]; then
      dir="''${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
      ${pkgs.coreutils}/bin/rm -f "$dir/last" "$dir/pane_contents.tar.gz"
    fi
    exec "$tmux" kill-session -t "$1"
  '';
in {
  imports = [./agent-sidebar.nix];

  programs.git.ignores = [
    ".tmuxinator.yml"
    ".tmuxinator/"
  ];

  # Lets fzf open inside a tmux popup
  programs.fzf.tmux.enableShellIntegration = true;

  programs.tmux = {
    enable = true;
    package = tmuxWrapped;
    tmuxinator.enable = true;
    tmuxp.enable = false;
    prefix = "C-Space";
    mouse = true;
    clock24 = false;
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins;
      [
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
          plugin = tmux-floax;
          extraConfig = ''
            set -g @floax-width '80%'
            set -g @floax-height '80%'
            set -g @floax-border-color 'magenta'
            set -g @floax-text-color 'blue'
            set -g @floax-bind 'p'
            set -g @floax-change-path 'true'
          '';
        }
        {
          plugin = catppuccin;
          extraConfig = ''
            set -g @catppuccin_flavour 'mocha'
            set -g @catppuccin_window_status_style "rounded"

            # Fix to show the window name by default; ring a bell glyph while a
            # background window has a pending bell (cleared on focus by tmux).
            set -g @catppuccin_window_default_text "#W#{?window_bell_flag, #[fg=#{@thm_red}]#[fg=#{@thm_text}],}"
            set -g @catppuccin_window_text "#W#{?window_bell_flag, #[fg=#{@thm_red}]#[fg=#{@thm_text}],}"
            # This will show a magnifying glass icon when the window is zoomed
            set -g @catppuccin_window_current_text "#W#{?window_zoomed_flag,(),}"

            # Left Status Modules
            set -g @catppuccin_status_modules_left "session"
            set -g status-left "#{E:@catppuccin_status_session} "

            # Right Status Modules
            set -g status-right-length 100
            set -g status-left-length 100
            set -g status-right "#{E:@catppuccin_status_application}"
            set -agF status-right "#{E:@catppuccin_status_cpu}"
            set -ag status-right "#{E:@catppuccin_status_date_time}"
            ${
              if isLaptop
              then ''set -agF status-right "#{E:@catppuccin_status_battery}"''
              else ""
            }

            set -g @catppuccin_status_connect_separator "no"
            set -g @catppuccin_window_left_separator ""
            # set -g @catppuccin_window_right_separator " "
            set -g @catppuccin_window_middle_separator " █"
            set -g @catppuccin_status_left_separator  " "
            set -g @catppuccin_status_right_separator ""
            # set -g @catppuccin_status_right_separator_inverse "no"
            set -g @catppuccin_window_number_position "right"


            set -g @catppuccin_directory_text "#{b:pane_current_path}"
            set -g @catppuccin_date_time_text " %I:%M %p %d/%m/%y "
          '';
        }
        cpu
      ]
      ++ (
        if isLaptop
        then [battery]
        else []
      )
      ++ [
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
      # Stylix's tmux target is sourced after catppuccin and overwrites these.
      set -g pane-active-border-style 'fg=magenta,bg=default'
      set -g pane-border-style 'fg=brightblack,bg=default'
      # fill clears the rest of the line; without it the value abuts the window list.
      set -gF message-style "fg=#{@thm_fg},bg=default,underscore,us=#{@thm_mauve},fill=#{@thm_bg}"
      set -gF message-command-style "fg=#{@thm_fg},bg=default,underscore,us=#{@thm_peach},bold,fill=#{@thm_bg}"

      # command-prompt splits -p on commas, so these can't be inlined there.
      set -gF @prompt_rename_window "#[fg=#{@thm_mauve},bg=default,nounderscore]#[fg=#{@thm_crust},bg=#{@thm_mauve},bold,nounderscore]  rename window #[fg=#{@thm_mauve},bg=default,nobold,nounderscore] "
      set -gF @prompt_rename_session "#[fg=#{@thm_mauve},bg=default,nounderscore]#[fg=#{@thm_crust},bg=#{@thm_mauve},bold,nounderscore]  rename session #[fg=#{@thm_mauve},bg=default,nobold,nounderscore] "
      set -gF @prompt_new_session "#[fg=#{@thm_mauve},bg=default,nounderscore]#[fg=#{@thm_crust},bg=#{@thm_mauve},bold,nounderscore]  new session #[fg=#{@thm_mauve},bg=default,nobold,nounderscore] "

      set -g mode-keys vi              # enable vi mode keys for copy mode
      set -g base-index 1              # start indexing windows at 1 instead of 0
      set -g detach-on-destroy off     # don't exit from tmux when closing a session
      set -g escape-time 0             # zero-out escape time delay
      set -g focus-events on           # forward terminal focus events to programs (e.g. Claude Code, nvim autoread)
      set -g monitor-bell on           # flag a window in the status bar when a background pane rings (e.g. Claude finished)
      set -g bell-action any           # honor bells from any window, not just the active one
      set -g allow-passthrough on      # let programs emit escape sequences through tmux
      set -g history-limit 1000000     # increase history size (from 2,000)
      set -g renumber-windows on       # renumber all windows when any window is closed
      set -g set-clipboard on          # use system clipboard
      set -g status-position top       # macOS / darwin style

      set -g set-titles on             # forward the title to the terminal (default off = swallowed)
      set -g set-titles-string "#S – #W"

      set -g status-bg default
      set -g status-style bg=default

      # Advertise truecolor support to programs running inside tmux (e.g. process-compose)
      set -ag terminal-features ",*:RGB"

      # Module styling (must be set before catppuccin loads)
      set -g @catppuccin_session_icon " "
      set -g @catppuccin_session_color "#{?client_prefix,#{@thm_red},#{@thm_green}}"

      ${builtins.readFile ./binds.conf}

      # Quit current session; forget the continuum snapshot if it was the last one
      bind-key Q run-shell "${tmuxQuit} #{session_name}"

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
}
