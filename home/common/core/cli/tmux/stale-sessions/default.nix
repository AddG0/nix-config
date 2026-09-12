# A session is in use while a client is on it or a pane is running a command;
# only one sitting at a shell prompt ages. A long-running command therefore holds
# a session open indefinitely.
{pkgs, ...}: let
  recordAttach = pkgs.callPackage ./record-attach.nix {};
  prune = pkgs.callPackage ./prune.nix {};
in {
  programs.tmux.extraConfig = ''
    # Quoted for run-shell's sh -c: unquoted, a name splits on spaces.
    set-hook -ag client-attached "run-shell -b '${recordAttach}/bin/tmux-record-session-attach \"#{client_session}\"'"
    # Renaming is deliberate interaction, so it counts even though nothing attached.
    set-hook -ag session-renamed "run-shell -b '${recordAttach}/bin/tmux-record-session-attach \"#{session_name}\"'"
  '';

  systemd.user = {
    services.tmux-prune-stale-sessions = {
      Unit.Description = "Remove tmux sessions not attached in three days";
      Service = {
        Type = "oneshot";
        # tmux's socket lives under TMUX_TMPDIR (home-manager points it at
        # XDG_RUNTIME_DIR); unset, the unit looks in /tmp and sees no sessions.
        Environment = "TMUX_TMPDIR=%t";
        ExecStart = "${prune}/bin/tmux-prune-stale-sessions";
      };
    };
    timers.tmux-prune-stale-sessions = {
      Unit.Description = "Hourly stale tmux session cleanup";
      Timer = {
        OnBootSec = "10m";
        OnUnitActiveSec = "1h";
        Persistent = true;
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
