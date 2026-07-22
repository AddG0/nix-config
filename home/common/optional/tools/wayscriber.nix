{pkgs, ...}: {
  # Native Wayland screen annotation tool (replaces gromit-mpx on Wayland)
  # Toggle with: wayscriber --daemon-toggle (NOT `pkill -SIGUSR1 wayscriber`,
  # which also kills the same-named process-broker child and breaks toggles).
  # F1 = help | Escape = exit overlay | Ctrl+Z = undo | Ctrl+Y = redo

  # Run as a background daemon
  systemd.user.services.wayscriber = {
    Unit = {
      Description = "Wayscriber screen annotation";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.wayscriber}/bin/wayscriber --daemon";
      Restart = "on-failure";
      # built-in Cairo toolbar; the default GTK backend adds a ~1s cold-start on every toggle.
      Environment = "WAYSCRIBER_TOOLBAR_BACKEND=builtin";
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  # Land annotated captures alongside grim screenshots (see screenshots.nix).
  # Partial config; omitted sections keep wayscriber's defaults.
  xdg.configFile."wayscriber/config.toml".text = ''
    [capture]
    save_directory = "~/Pictures/Screenshots"
    filename_template = "%Y-%m-%d_%H-%M-%S"
  '';
}
