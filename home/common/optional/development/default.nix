{pkgs, ...}: {
  imports = [
    ./process-compose.nix
    ./gsync.nix
  ];

  home.packages = with pkgs; [
    ttyplot
    ngrok
    mailsy # create and send emails from the terminal
    cpulimit # limit the cpu usage of a process
    caddy # A webserver with automatic HTTPS via Let's Encrypt(replacement of nginx)
    devenv
  ];

  programs.git.ignores = [
    # Running the redis-server in a directory will make this file appear
    "dump.rdb"
  ];

  programs.lnav = {
    enable = true;
    settings = {
      ui = {
        theme = "dracula"; # Available themes: default, dracula, eldar, grayscale, monocai, night-owl, solarized-dark, solarized-light
      };
      tuning = {
        "archive-manager" = {
          "min-free-space" = 104857600; # 100MB
          "cache-ttl" = "3d";
        };
      };
    };
  };
}
