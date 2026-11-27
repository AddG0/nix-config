# Headless servers keep booting unattended: no console to answer, no full /boot, nobody to wake them.
{
  config,
  lib,
  ...
}:
lib.mkIf (config.hostSpec.hostType == "server") {
  boot.loader = {
    timeout = lib.mkDefault 1;
    grub.configurationLimit = lib.mkDefault 5;
    systemd-boot.configurationLimit = lib.mkDefault 5;
  };

  systemd = {
    enableEmergencyMode = lib.mkDefault false;

    sleep.settings.Sleep = {
      AllowSuspend = lib.mkDefault "no";
      AllowHibernation = lib.mkDefault "no";
    };

    settings.Manager = {
      RuntimeWatchdogSec = lib.mkDefault "15s";
      RebootWatchdogSec = lib.mkDefault "30s";
      KExecWatchdogSec = lib.mkDefault "1m";
    };
  };
}
