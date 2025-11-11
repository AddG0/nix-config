{pkgs, ...}: {
  home.packages = with pkgs; [
    ttyplot
    lnav
    ngrok
    mailsy # create and send emails from the terminal
    cpulimit # limit the cpu usage of a process
    caddy # A webserver with automatic HTTPS via Let's Encrypt(replacement of nginx)
  ];
}
