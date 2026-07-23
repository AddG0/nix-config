# tmux-agent-sidebar: agent-monitoring sidebar pane, themed to match Stylix
# (catppuccin-mocha). Split out to keep default.nix lean. State is fed by Claude
# Code hooks (../../../optional/development/ai/claude-code/tmux-agent-sidebar.nix).
{
  config,
  lib,
  pkgs,
  ...
}: let
  # The binary ships xterm-256 defaults that clash with the theme; map its
  # semantic color options onto Stylix base16 roles. Read raw (`tmux show -g`),
  # so they must be literal hex — @thm_ references would not expand.
  c = config.lib.stylix.colors.withHashtag;
  colors = {
    accent = c.base0E;
    border = c.base03;
    all = c.base0D;
    running = c.base0B;
    waiting = c.base0A;
    idle = c.base04;
    error = c.base08;
    filter_inactive = c.base03;
    agent_claude = c.base09;
    agent_codex = c.base0E;
    agent_opencode = c.base0C;
    pet_body = c.base09;
    pet_eye = c.base0B;
    text_active = c.base05;
    text_muted = c.base04;
    text_inactive = c.base03;
    session = c.base0D;
    port = c.base04;
    wait_reason = c.base0A;
    selection = c.base02;
    branch = c.base0C;
    task_progress = c.base0A;
    subagent = c.base0C;
    commit_hash = c.base0A;
    diff_added = c.base0B;
    diff_deleted = c.base08;
    file_change = c.base0A;
    pr_link = c.base0D;
    section_title = c.base0D;
    activity_timestamp = c.base04;
    response_arrow = c.base0C;
  };
  colorCfg = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: hex: "set -g @sidebar_color_${name} '${hex}'") colors
  );
in {
  programs.tmux.plugins = [
    {
      # Toggle keys: prefix e (this window), prefix E (all windows).
      plugin = pkgs.tmuxPlugins.tmux-agent-sidebar;
      extraConfig = ''
        ${colorCfg}
        # Manual-only: never inject the sidebar automatically; open it with
        # prefix e (this window) / prefix E (all windows).
        set -g @sidebar_auto_create 'off'

        # Focusing the sidebar pane would rename the window to its binary; keep
        # its current name instead, else tmux's stock default.
        set -g automatic-rename-format '#{?#{==:#{@pane_role},sidebar},#{window_name},#{?pane_in_mode,[tmux],#{pane_current_command}}#{?pane_dead,[dead],}}'
      '';
    }
  ];
}
