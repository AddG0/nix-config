{
  config,
  pkgs,
  ...
}: let
  # Accent tokens track the active stylix base16 scheme; herdr's base theme
  # supplies the rest.
  c = config.lib.stylix.colors.withHashtag;

  tomlFormat = pkgs.formats.toml {};

  settings = {
    onboarding = false;

    theme = {
      name = "catppuccin"; # matches the catppuccin-mocha stylix scheme + tmux
      custom = {
        accent = c.base0D;
        red = c.base08;
        green = c.base0B;
      };
    };

    terminal.new_cwd = "follow"; # new panes inherit the source pane's cwd

    ui = {
      accent = c.base0D;
      confirm_close = true;
      show_agent_labels_on_pane_borders = true;

      toast.delivery = "herdr"; # in-app toasts for background agent state

      sound = {
        enabled = true;
        agents.claude = "on";
      };
    };

    # Mirror tmux muscle memory where herdr's binding model allows.
    # Some punctuation has herdr token names (minus/comma/ampersand); the rest
    # uses the literal char (| / $). tmux's resize-on-prefix+hjkl has no
    # herdr equivalent.
    keys = {
      detach = "prefix+d"; # tmux-standard detach (herdr default: prefix+q)
      rename_tab = "prefix+comma"; # tmux `bind ,`
      close_tab = "prefix+ampersand"; # tmux `bind &` kill-window

      reload_config = "prefix+r"; # tmux `bind r`; frees default off prefix+shift+r
      resize_mode = "prefix+shift+r"; # moved aside so prefix+r is reload

      workspace_picker = "prefix+s"; # tmux `bind s` choose-tree
      new_workspace = "prefix+shift+s"; # tmux `bind S` new-session; completes the s/S picker pair
      rename_workspace = "prefix+$"; # tmux `bind $` rename-session
      settings = "prefix+shift+t"; # no tmux analog; free slot, no collision

      split_vertical = "prefix+|"; # tmux `bind | split-window -h` (left/right)
      split_horizontal = "prefix+minus"; # tmux `bind - split-window -v` (top/bottom); also herdr's default

      # tmux navigates panes with un-prefixed Alt+arrows (M-Left/Right/Up/Down).
      focus_pane_left = "alt+left";
      focus_pane_down = "alt+down";
      focus_pane_up = "alt+up";
      focus_pane_right = "alt+right";

      # Floating-pane workflow parallel to the tmux floax bind.
      command = [
        {
          key = "prefix+alt+g";
          type = "pane";
          command = "lazygit";
        }
      ];
    };

    # Resume Claude Code panes into their native session after a server restart.
    session.resume_agents_on_restore = true;
  };
in {
  home.packages = [pkgs.herdr]; # tmux-like, agent-aware terminal multiplexer

  xdg.configFile."herdr/config.toml".source =
    tomlFormat.generate "herdr-config.toml" settings;
}
