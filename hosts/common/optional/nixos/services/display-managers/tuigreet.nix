# tuigreet on greetd as the login screen. https://github.com/apognu/tuigreet
{
  config,
  lib,
  pkgs,
  ...
}: let
  sessionCommand = "${lib.getExe config.desktops.startSession} ${config.services.displayManager.sessionData.autologinSession}";
in {
  imports = [./_greetd.nix];

  services.greetd.settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --asterisks --remember --time --time-format '%I:%M %p | %a • %h | %F' --cmd '${sessionCommand}'";
}
