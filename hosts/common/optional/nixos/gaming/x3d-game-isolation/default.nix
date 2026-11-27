# While gamemode has a game on a dual-CCD X3D CPU, it owns as many V-Cache cores as it uses and most of that cache; the compositor and Steam client keep every core, everything else gets the rest. Why: ADR 0027.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # callPackageWith, not pkgs.callPackage: the tests hand the scripts a pkgs with fake systemd and D-Bus tools.
  script = path: args: lib.getExe (lib.callPackageWith pkgs path args);
  # Members may run the root helper and add their own threads to the game's cache group.
  group = "gamemode";
  cacheCcd = script ./cache-ccd.nix {};
  isolate = script ./isolate.nix {inherit cacheCcd group;};
  watcher = script ./watcher.nix {
    inherit cacheCcd isolate;
    sudo = "${config.security.wrapperDir}/sudo";
  };
in {
  assertions = [
    {
      assertion = config.programs.gamemode.enable;
      message = "x3d-game-isolation follows games through gamemode's D-Bus API; enable programs.gamemode.";
    }
  ];

  # The helper only accepts CPU lists within the V-Cache CCD and always leaves system services the other CCD.
  security.sudo.extraConfig = ''
    %${group} ALL = (root) NOPASSWD: ${isolate} split *, ${isolate} release
  '';

  systemd = {
    # Lets the watcher set AllowedCPUs on the session's own slices; upstream delegates only cpu, memory and pids.
    services."user@".serviceConfig.Delegate = "cpu cpuset io memory pids";

    user = {
      # Above session.slice (1000): on the game's cores only the compositor and Steam client run beside it.
      slices.game = {
        description = "Games isolated on the V-Cache CCD";
        sliceConfig.CPUWeight = 10000;
      };

      services.x3d-game-isolation = {
        description = "Give a running game the V-Cache CCD to itself";
        after = ["graphical-session.target"];
        partOf = ["graphical-session.target"];
        wantedBy = ["graphical-session.target"];
        serviceConfig = {
          ExecStart = "${watcher} watch";
          # Stopping the watcher ends isolation, even mid-game.
          ExecStopPost = "${watcher} release";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
  };
}
