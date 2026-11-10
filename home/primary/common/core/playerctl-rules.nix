{
  config,
  pkgs,
  ...
}: {
  # Skip Spotify's AI DJ ("DJ X") segments on graphical Linux hosts.
  # playerctl is MPRIS/D-Bus, so Linux-only — exclude servers and darwin.
  services.playerctlRules = {
    enable = config.hostSpec.hostType != "server" && pkgs.stdenv.hostPlatform.isLinux;
    debug = true; # diagnosing DJ X skip; check `journalctl --user -u playerctl-rule-spotify`
    players.spotify = {
      patterns = ["DJ X"];
      # "Up next" /media/<id> announces /track/<id>, and Next can carry past it.
      announcedTrack = {
        from = "/media/";
        to = "/track/";
      };
    };
  };
}
