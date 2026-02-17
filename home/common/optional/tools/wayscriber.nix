{
  inputs,
  pkgs,
  ...
}: let
  wayscriber = inputs.wayscriber.packages.${pkgs.system}.default;
in {
  # Native Wayland screen annotation tool (replaces gromit-mpx on Wayland)
  # Toggle with: pkill -SIGUSR1 wayscriber
  # F1 = help | Escape = exit overlay | Ctrl+Z = undo | Ctrl+Y = redo

  # Run as a background daemon
  systemd.user.services.wayscriber = {
    Unit = {
      Description = "Wayscriber screen annotation";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${wayscriber}/bin/wayscriber --daemon";
      Restart = "on-failure";
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
