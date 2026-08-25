{lib, ...}: {
  # Monotonic, not OnCalendar: CLOCK_MONOTONIC pauses in suspend, so no runs are owed on resume.
  systemd.timers = {
    nix-optimise.timerConfig = {
      OnCalendar = lib.mkForce [];
      Persistent = lib.mkForce false;
      OnBootSec = "1h";
      OnUnitActiveSec = "1w";
    };
    nh-clean.timerConfig = {
      OnCalendar = lib.mkForce [];
      Persistent = lib.mkForce false;
      OnBootSec = "2h";
      OnUnitActiveSec = "1w";
    };
  };
}
