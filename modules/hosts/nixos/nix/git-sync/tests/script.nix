# Runs git-sync's scripts against fakes (rebuild, check-newer, wake, Kubernetes node drain, reboot and signature checks), cases in the .bats files, and checks the module's assertions.
{
  harness,
  pkgs,
  lib,
  ...
}: let
  # Logs each call to $NIX_LOG. `nix flake metadata` prints $FLAKE_METADATA; `nix build --out-link LINK` links LINK to $BUILT_SYSTEM. NIX_*_EXIT fail them.
  fakeNix = pkgs.writeShellScriptBin "nix" ''
    echo "$*" >>"''${NIX_LOG:-/dev/null}"
    case "$1" in
      build)
        [ -z "''${NIX_BUILD_EXIT:-}" ] || exit "$NIX_BUILD_EXIT"
        ln -s "$BUILT_SYSTEM" "$3"
        ;;
      *)
        [ -z "''${NIX_METADATA_EXIT:-}" ] || exit "$NIX_METADATA_EXIT"
        printf '%s\n' "$FLAKE_METADATA"
        ;;
    esac
  '';

  # nixos-rebuild logging each call to $NIXOS_REBUILD_LOG. Call N prints $NIXOS_REBUILD_LOG.N when a case wrote
  # one, standing in for switch-to-configuration's report, and exits with the Nth of $NIXOS_REBUILD_EXITS (default 0).
  fakeNixosRebuild = pkgs.writeShellScriptBin "nixos-rebuild" ''
    echo "$*" >>"$NIXOS_REBUILD_LOG"
    call=$(wc -l <"$NIXOS_REBUILD_LOG")
    [ ! -f "$NIXOS_REBUILD_LOG.$call" ] || cat "$NIXOS_REBUILD_LOG.$call" >&2
    read -ra exits <<<"''${NIXOS_REBUILD_EXITS:-}"
    exit "''${exits[$((call - 1))]:-0}"
  '';

  # The build sandbox has no syslog socket for logger, nor a network for ping.
  fakeLogger = pkgs.writeShellScriptBin "logger" ":";
  # Answers every ping, unless $PING_FAILURES is set: then it logs each call to $PING_LOG and fails the first that many.
  fakePing = pkgs.writeShellScriptBin "ping" ''
    [ -n "''${PING_FAILURES:-}" ] || exit 0
    echo "ping $*" >>"$PING_LOG"
    [ "$(${pkgs.gnugrep}/bin/grep -c '^ping ' "$PING_LOG")" -gt "$PING_FAILURES" ]
  '';

  # systemd whose systemctl logs each action to $SYSTEMCTL_LOG, failing `start` and `reboot` with $SYSTEMCTL_*_EXIT. Queries
  # go unlogged: `list-units` lists $FAILED_UNITS or $RESTARTING_UNITS by --state, and `show` prints $EXEC_MAIN_STATUS.
  fakeSystemd = pkgs.runCommand "fake-systemd" {} ''
    mkdir -p $out/bin
    ln -s ${pkgs.systemd}/bin/systemd-analyze $out/bin/
    cat >$out/bin/systemctl <<'EOF'
    #!${pkgs.runtimeShell}
    if [ "$1" = list-units ]; then
      case "$*" in
        *--state=failed*) units=''${FAILED_UNITS:-} ;;
        *--state=auto-restart*) units=''${RESTARTING_UNITS:-} ;;
      esac
      for unit in ''${units:-}; do echo "$unit loaded failed failed $unit"; done
      exit 0
    fi
    if [ "$1" = show ]; then
      echo "''${EXEC_MAIN_STATUS:-0}"
      exit 0
    fi
    echo "$*" >>"$SYSTEMCTL_LOG"
    [ "$1" = start ] && exit "''${SYSTEMCTL_START_EXIT:-0}"
    [ "$1" = reboot ] && exit "''${SYSTEMCTL_REBOOT_EXIT:-0}"
    exit 0
    EOF
    chmod +x $out/bin/systemctl
  '';

  # kubectl logging each call to $KUBECTL_LOG, its get, drain and uncordon steered by the variables drain-kubernetes-node.bats sets.
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

  fakedPkgs =
    pkgs
    // {
      nix = fakeNix;
      nixos-rebuild = fakeNixosRebuild;
      systemd = fakeSystemd;
      util-linux = fakeLogger;
      iputils = fakePing;
    };

  # The module over only the NixOS options it reads or writes, with its tools faked, for one host's settings.
  gitSyncOn = settings:
    (lib.evalModules {
      specialArgs.pkgs = fakedPkgs;
      modules = [
        (harness.module ../default.nix)
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
        {nix.git-sync = {enable = true;} // settings;}
      ];
    })
    .config;

  # Its schedule is a fixture, so the wake cases follow whatever time a host sets rather than the module's default.
  sleepingHost = gitSyncOn {
    schedule = "04:30";
    wakeForSchedule = true;
  };
  kernelRebootHost = gitSyncOn {reboot = "onKernelChange";};
  alwaysRebootHost = gitSyncOn {
    reboot = "always";
    drainKubernetesNode = {
      enable = true;
      kubectl = "${fakeKubectl}";
    };
  };
  # Hooks a case makes fail through the environment.
  hookedHost = gitSyncOn {
    reboot = "always";
    postRebuildHook = ''if [ -n "''${POST_REBUILD_FAILS:-}" ]; then exit 1; fi'';
    preRebootHook = ''if [ -n "''${PRE_REBOOT_FAILS:-}" ]; then exit 1; fi'';
  };
  # Trusts the committed test-only key second, so it only matches when the generated signers file puts each key on its own line.
  signedHost = gitSyncOn {
    allowedSigners = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFxtPtRTMkvp/PQOQ5iaToNDNEhPPFGLPZu6j8lRd4ve"
      (lib.removeSuffix "\n" (builtins.readFile ./signing-key.pub))
    ];
  };
  # The check giving the network one instant try, so the never-online case skips the real wait's minute of retries.
  checkNewerTryingNetworkOnce = lib.getExe (lib.callPackageWith fakedPkgs ../check-newer.nix {
    flakeRef = "github:o/r";
    lastBuiltRecord = "$STATE_DIRECTORY/last-built-narhash";
    waitForNetwork = lib.custom.mkNetworkWaitScript {
      host = "github.com";
      maxAttempts = 1;
      waitSeconds = 0;
    };
  });
  rebuildOn = host: host.systemd.services.nix-remote-rebuild.serviceConfig.ExecStart;
  unitCommand = host: name: host.systemd.services.${name}.serviceConfig.ExecStart;

  failedAssertions = settings: lib.length (lib.filter (a: !a.assertion) (gitSyncOn settings).assertions);
  assertionCases = harness.check "git-sync-assertions" (harness.values {
    "test rejects test activation on a host that reboots" = {
      expr = failedAssertions {
        reboot = "always";
        rebuildCommand = "test";
      };
      expected = 1;
    };
    "test allows test activation on a host that never reboots" = {
      expr = failedAssertions {rebuildCommand = "test";};
      expected = 0;
    };
    "test rejects waking for the schedule on a host that reboots" = {
      expr = failedAssertions {
        wakeForSchedule = true;
        reboot = "onKernelChange";
      };
      expected = 1;
    };
    "test rejects an interval while a schedule is still set" = {
      expr = failedAssertions {interval = "1h";};
      expected = 1;
    };
    "test accepts an interval once the schedule is cleared" = {
      expr = failedAssertions {
        interval = "1h";
        schedule = null;
      };
      expected = 0;
    };
  });
in
  harness.bats "git-sync" [./rebuild.bats ./check-newer.bats ./wake.bats ./drain-kubernetes-node.bats ./needs-reboot.bats ./verify-signature.bats] {
    # Fixture repos for rebuild.bats, check-newer.bats and verify-signature.bats.
    nativeBuildInputs = [pkgs.git pkgs.openssh];
    # Built first: fails this check when a module assertion case does.
    inherit assertionCases;
    generations = "${./_generations.bash}";
    # A committed test-only key pair: it signs fixture commits and is trusted nowhere else.
    signingKey = "${./signing-key}";
    rebuildOnKernelChange = rebuildOn kernelRebootHost;
    rebuildAlways = rebuildOn alwaysRebootHost;
    rebuildNever = rebuildOn sleepingHost;
    rebuildHooked = rebuildOn hookedHost;
    rebuildSigned = rebuildOn signedHost;
    checkNewer = sleepingHost.systemd.services.nix-remote-rebuild.serviceConfig.ExecCondition;
    inherit checkNewerTryingNetworkOnce;
    needsReboot = lib.getExe (pkgs.callPackage ../needs-reboot.nix {});
    verifySignature = lib.getExe (pkgs.callPackage ../verify-signature.nix {});
    armWake = sleepingHost.systemd.services.nix-remote-rebuild-arm-wake.serviceConfig.ExecStop;
    wokenByAlarm = sleepingHost.systemd.services.nix-remote-rebuild-on-alarm-boot.serviceConfig.ExecCondition;
    # Each unit's whole command, the argument it passes included.
    returnAfterAlarmBoot = unitCommand sleepingHost "nix-remote-rebuild-on-alarm-boot";
    returnAfterAlarmResume = unitCommand sleepingHost "nix-remote-rebuild-on-alarm-resume";
    beforeReboot = alwaysRebootHost.nix.git-sync.preRebootHook;
    uncordonAfterBoot = unitCommand alwaysRebootHost "nix-remote-rebuild-uncordon";
    schedule = sleepingHost.nix.git-sync.schedule;
    TZDIR = "${pkgs.tzdata}/share/zoneinfo";
  }
