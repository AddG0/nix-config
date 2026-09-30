{
  lib,
  pkgs,
  ...
}: {
  home.packages = [pkgs.playerctl];
  services.playerctld = {
    enable = true;
  };

  # default.target is also reached at boot on lingering hosts, where MPRIS has
  # no session and no players to proxy.
  systemd.user.services.playerctld = {
    Unit = {
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Install.WantedBy = lib.mkForce ["graphical-session.target"];
  };
}
