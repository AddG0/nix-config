# tuigreet on greetd as the login screen. https://github.com/apognu/tuigreet
{
  config,
  pkgs,
  ...
}: let
  inherit (config.services.displayManager) sessionData;
in {
  imports = [
    ./_greetd.nix
    (import ./_retain-splash.nix {textGreeter = true;})
  ];

  # No --cmd: tuigreet shows it as a raw store path, and without it defaults to the first session by name.
  services.greetd.settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --asterisks --remember --remember-user-session --time --time-format '%I:%M %p | %a • %h | %F' --sessions ${sessionData.desktops}/share/wayland-sessions --xsessions ${sessionData.desktops}/share/xsessions";
}
