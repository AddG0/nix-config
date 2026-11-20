# Runs the tmux server under systemd, so it never lives in the cgroup of whoever ran `tmux` first.
# Not named tmux.*: tmux-continuum runs `systemctl --user disable tmux.service` on load, which deletes home-manager's link.
{pkgs, ...}: {
  systemd.user = {
    sockets.tmux-server = {
      Unit.Description = "tmux server socket";
      Socket = {
        # The path a client derives from TMUX_TMPDIR, which home-manager points at XDG_RUNTIME_DIR.
        ListenStream = "%t/tmux-%U/default";
        SocketMode = "0600";
        DirectoryMode = "0700";
      };
      Install.WantedBy = ["sockets.target"];
    };
    services.tmux-server = {
      Unit = {
        Description = "tmux server";
        Documentation = "man:tmux(1)";
        Requires = ["tmux-server.socket"];
      };
      Service = {
        Environment = "TMUX_TMPDIR=%t";
        ExecStart = "${pkgs.tmux}/bin/tmux -D";
        # tmux reads tmux.conf when its first client connects; this client makes that happen now.
        ExecStartPost = "${pkgs.tmux}/bin/tmux start-server";
      };
    };
  };
}
