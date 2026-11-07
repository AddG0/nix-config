# Runs git-sync's check-newer, wake and node-drain scripts against fakes; cases in the .bats files.
{
  harness,
  pkgs,
  lib,
  ...
}: let
  # Prints $FLAKE_METADATA, standing in for `nix flake metadata --refresh --json`.
  fakeNix = pkgs.writeShellScriptBin "nix" ''
    printf '%s\n' "$FLAKE_METADATA"
  '';

  # systemd whose systemctl logs each call to $SYSTEMCTL_LOG, failing `start` with $SYSTEMCTL_START_EXIT.
  fakeSystemd = pkgs.runCommand "fake-systemd" {} ''
    mkdir -p $out/bin
    ln -s ${pkgs.systemd}/bin/systemd-analyze $out/bin/
    cat >$out/bin/systemctl <<'EOF'
    #!${pkgs.runtimeShell}
    echo "$*" >>"$SYSTEMCTL_LOG"
    [ "$1" = start ] && exit "''${SYSTEMCTL_START_EXIT:-0}"
    exit 0
    EOF
    chmod +x $out/bin/systemctl
  '';

  # kubectl logging each call to $KUBECTL_LOG, its get, drain and uncordon steered by the variables drain.bats sets.
  fakeKubectl = pkgs.writeShellScript "kubectl" ''
    echo "$*" >>"$KUBECTL_LOG"
    case "$1" in
      get)
        [ "''${KUBECTL_GET_EXIT:-0}" = 0 ] || exit "$KUBECTL_GET_EXIT"
        printf '%s' "''${NODE_UNSCHEDULABLE:-}"
        ;;
      drain)
        [ -z "''${KUBECTL_DRAIN_HANGS:-}" ] || exec sleep 600
        exit "''${KUBECTL_DRAIN_EXIT:-0}"
        ;;
      uncordon)
        failed=$(grep -c '^uncordon' "$KUBECTL_LOG")
        [ "$failed" -gt "''${UNCORDON_FAILURES:-0}" ] || exit 1
        ;;
    esac
  '';

  inherit
    (lib.evalModules {
      specialArgs.pkgs =
        pkgs
        // {
          nix = fakeNix;
          systemd = fakeSystemd;
        };
      modules = [
        (harness.module ../default.nix)
        # Only the NixOS options git-sync reads or writes.
        {
          options = {
            assertions = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [];
            };
            systemd = lib.mkOption {type = lib.types.anything;};
            networking.hostName = lib.mkOption {
              type = lib.types.str;
              default = "t";
            };
          };
        }
        {
          nix.git-sync = {
            enable = true;
            wakeForSchedule = true;
            drainKubernetesNode = {
              enable = true;
              kubectl = "${fakeKubectl}";
            };
          };
        }
      ];
    })
    config
    ;
in
  harness.bats "git-sync" [./check-newer.bats ./wake.bats ./drain.bats] {
    checkNewer = config.systemd.services.nix-remote-rebuild.serviceConfig.ExecCondition;
    armWake = config.systemd.services.nix-remote-rebuild-arm-wake.serviceConfig.ExecStop;
    wokenByAlarm = config.systemd.services.nix-remote-rebuild-on-alarm-boot.serviceConfig.ExecCondition;
    # Each alarm unit passes what it woke from; the cases pass their own.
    syncThenReturnTo = lib.head (lib.splitString " " config.systemd.services.nix-remote-rebuild-on-alarm-resume.serviceConfig.ExecStart);
    # The step the reboot runs, and the unit that undoes its cordon after the boot.
    beforeReboot = config.nix.git-sync.preRebootHook;
    node = lib.head (lib.splitString " " config.systemd.services.nix-remote-rebuild-uncordon.serviceConfig.ExecStart);
    schedule = config.nix.git-sync.schedule;
    TZDIR = "${pkgs.tzdata}/share/zoneinfo";
  }
