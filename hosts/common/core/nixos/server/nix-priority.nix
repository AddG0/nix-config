# Nix builds and store maintenance yield to the services a server exists to run.
{
  config,
  lib,
  ...
}: let
  backgroundPriority = {
    CPUSchedulingPolicy = "batch";
    IOSchedulingClass = "idle";
    IOSchedulingPriority = 7;
  };
in
  lib.mkIf (config.hostSpec.hostType == "server") {
    nix = {
      daemonCPUSchedPolicy = lib.mkDefault "batch";
      daemonIOSchedClass = lib.mkDefault "idle";
      daemonIOSchedPriority = lib.mkDefault 7;
    };

    systemd.services = {
      # Between user slices (100) and systemd-coredump (500): lose a build before a service.
      nix-daemon.serviceConfig.OOMScoreAdjust = lib.mkDefault 250;
      nh-clean.serviceConfig = backgroundPriority;
    };
  }
