{...}: {
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
}
