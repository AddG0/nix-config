{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./styling.nix
    ./tmux.nix
  ];

  programs.lnav = {
    enable = true;
    settings.tuning = {
      "archive-manager" = {
        "min-free-space" = 104857600; # 100MB
        "cache-ttl" = "3d";
      };
    };
  };

  xdg.desktopEntries.lnav = lib.mkIf (pkgs.stdenv.isLinux && config.hostSpec.hostType != "server") {
    name = "lnav";
    genericName = "Log File Navigator";
    comment = "View and analyze log files";
    exec = "${pkgs.ghostty}/bin/ghostty -e ${config.programs.lnav.package}/bin/lnav %F";
    terminal = false;
    categories = [
      "System"
      "Utility"
      "ConsoleOnly"
    ];
    mimeType = ["text/x-log"];
  };

  xdg.mimeApps.defaultApplications."text/x-log" = lib.mkIf (pkgs.stdenv.isLinux && config.hostSpec.hostType != "server") ["lnav.desktop"];
}
