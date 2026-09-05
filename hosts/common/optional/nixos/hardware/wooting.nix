{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    wootility
    wooting-bg-service
  ];

  hardware.wooting.enable = true;

  # Serves Wootility on 127.0.0.1:50052 so Light Indicator keeps feeding the
  # keyboard with Wootility closed. App linking stays dead on wlroots: its
  # window watcher (x-win) reads focus only on X11 or GNOME Shell.
  systemd.user.services.wooting-bg-service = {
    description = "Wooting Background Service";
    after = ["graphical-session.target"];
    partOf = ["graphical-session.target"];
    wantedBy = ["graphical-session.target"];
    serviceConfig = {
      ExecStart = "${pkgs.wooting-bg-service}/bin/wooting-bg-service";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
