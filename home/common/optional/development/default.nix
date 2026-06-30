{
  pkgs,
  inputs,
  lib,
  hostSpec,
  ...
}: let
  # Wrap mailsy to fix KDE 6 detection bug in bundled xdg-open
  mailsy-wrapped = pkgs.symlinkJoin {
    name = "mailsy-wrapped";
    paths = [pkgs.mailsy];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/mailsy \
        --set KDE_SESSION_VERSION "" \
        --set KDE_FULL_SESSION "" \
        --set XDG_CURRENT_DESKTOP "generic" \
        --set BROWSER "xdg-open"
    '';
  };
in {
  imports = lib.flatten [
    ./ide
    ./scripts
    (lib.optional (!hostSpec.isDarwin) ./chromium.nix)
    ./process-compose.nix
    ./git.nix
    ./gitlab.nix
    ./herdr.nix
    ./lnav
    ./polyrepo
    ./languages/nix
  ];

  home.packages = with pkgs; [
    ttyplot
    ngrok
    mailsy-wrapped # create and send emails from the terminal
    cpulimit # limit the cpu usage of a process
    caddy # A webserver with automatic HTTPS via Let's Encrypt(replacement of nginx)
    mutagen # real-time file sync over SSH (local repo -> dev server)
    temporal-cli
  ];

  programs.git.ignores = lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates ["Global/Redis"];
}
