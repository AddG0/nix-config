{
  config,
  pkgs,
  ...
}: {
  # Skip Spotify's AI DJ ("DJ X") segments on graphical Linux hosts.
  # playerctl is MPRIS/D-Bus, so Linux-only — exclude servers and darwin.
  services.playerctlRules = {
    enable = config.hostSpec.hostType != "server" && pkgs.stdenv.isLinux;
    players.spotify.patterns = ["DJ X"];
  };
}
