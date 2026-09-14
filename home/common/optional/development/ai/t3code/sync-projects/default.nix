{
  config,
  lib,
  pkgs,
  ...
}: let
  t3code-sync-projects = pkgs.writeShellApplication {
    name = "t3code-sync-projects";
    runtimeInputs = [pkgs.sqlite pkgs.jq pkgs.gwq config.programs.t3code.package];
    text = builtins.readFile ./scripts/sync-projects.sh;
  };
in {
  home.packages = [t3code-sync-projects];

  systemd.user.services.t3code-sync-projects = {
    Unit = {
      Description = "Register ghq clones as t3code projects";
      # First run of the script wants the state db; before t3code has ever
      # started there is nothing to sync into, so skip instead of failing.
      ConditionPathExists = "%h/.t3/userdata/state.sqlite";
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe t3code-sync-projects;
    };
  };

  systemd.user.timers.t3code-sync-projects = {
    Unit.Description = "Periodic ghq → t3code project sync";
    Timer = {
      OnStartupSec = "2m";
      OnUnitActiveSec = "15m";
    };
    Install.WantedBy = ["timers.target"];
  };
}
