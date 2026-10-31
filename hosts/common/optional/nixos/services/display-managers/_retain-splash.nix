# Plymouth leaves its last frame up until the next screen draws, instead of blanking, when that screen is graphical.
# textGreeter: the greeter draws on the console, so only an autologin straight into a session keeps the splash.
{textGreeter ? false}: {
  config,
  lib,
  ...
}: {
  systemd.services.plymouth-quit.serviceConfig.ExecStart = lib.mkIf (config.boot.plymouth.enable && (!textGreeter || config.services.displayManager.autoLogin.enable)) [
    ""
    "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
  ];
}
