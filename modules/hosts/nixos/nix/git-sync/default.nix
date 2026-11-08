# git-sync: rebuilds the host from its remote flake on a schedule.
{customLib, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nix.git-sync;
  inherit (config.networking) hostName;
  lastBuiltRecord = "$STATE_DIRECTORY/last-built-narhash";

  # callPackageWith, not pkgs.callPackage: the tests hand this module a pkgs with fake nix and systemd.
  script = path: args: lib.getExe (lib.callPackageWith pkgs path args);

  checkNewer = script ./check-newer.nix {
    inherit (cfg) flakeRef;
    inherit lastBuiltRecord;
  };

  rebuild = script ./rebuild.nix {
    inherit cfg hostName lastBuiltRecord;
    waitForNetwork = customLib.mkNetworkWaitScript {host = "github.com";};
    allowedSignersFile = pkgs.writeText "git-sync-allowed-signers" (
      lib.concatMapStrings (key: "git-sync namespaces=\"git\" ${key}\n") cfg.allowedSigners
    );
    verifySignature = script ./verify-signature.nix {};
    needsReboot = script ./needs-reboot.nix {};
  };
in {
  imports = [./wake.nix ./drain-kubernetes-node.nix];

  options.nix.git-sync = {
    enable = lib.mkEnableOption "rebuilding this host from its remote flake on a schedule";

    flakeRef = lib.mkOption {
      type = lib.types.str;
      default = "github:AddG0/nix-config";
      description = ''
        The flake to rebuild from. Each run locks it with
        `nix flake metadata --refresh`, then builds that locked revision's
        `nixosConfigurations.<hostname>`.
      '';
      example = "github:AddG0/nix-config";
    };

    interval = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Rebuild this long after the previous run started, and 5 minutes after
        boot, as a systemd time span. Exactly one of `interval` and `schedule`
        must be set, so set `schedule = null` to use this.
      '';
      example = "30min";
    };

    schedule = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "03:00";
      description = ''
        When to rebuild, in systemd OnCalendar syntax. A run the host misses
        while off happens at its next boot, unless `wakeForSchedule` is on.
        Exactly one of `schedule` and `interval` must be set.
      '';
      example = "Mon 10:00";
    };

    rebuildCommand = lib.mkOption {
      type = lib.types.enum ["switch" "boot" "test"];
      default = "switch";
      description = ''
        How to activate the build:
        - `switch`: now, and at every later boot. A build whose kernel, initrd
          or kernel modules differ from the booted system's is activated with
          `boot` instead, so no service restarts on new userspace under the
          old kernel. Until the host reboots, every later build differs too,
          and waits as well.
        - `boot`: at the next boot.
        - `test`: now, until the next boot. Requires `reboot = "never"`.
      '';
    };

    reboot = lib.mkOption {
      type = lib.types.enum ["never" "always" "onKernelChange"];
      default = "never";
      description = ''
        Whether a successful run reboots the host:
        - `never`: stay up. A build left for the next boot (see
          `rebuildCommand`) logs a warning.
        - `always`: reboot after every run. With `rebuildCommand = "boot"`,
          nothing restarts before the reboot.
        - `onKernelChange`: reboot when the build's kernel, initrd or kernel
          modules differ from the booted system's, the parts `switch` cannot
          activate. A nixpkgs bump that keeps the kernel leaves the host up;
          a kernel patch under an unchanged version string reboots it.

        A reboot first drains the Kubernetes node when `drainKubernetesNode.enable`
        is on, then happens at once, or after 2 minutes with a desktop warning
        when `notifications.enable` is on.
      '';
    };

    autoRollback = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When activating the build fails, put back what the activation changed:
        `switch` re-activates the running system and sets the next boot back,
        `boot` sets the next boot back, and `test` re-activates the running
        system. A run that fails to fetch, evaluate or build has changed
        nothing, so it restores nothing. An activation that fails only for
        units already failed or restarting before the run counts as a success.
      '';
    };

    checkRemoteNewer = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Skip the run unless the remote has moved past what this host runs. The
        run goes ahead only when the remote's `locked.narHash` differs from the
        one recorded after the last successful run, and the remote's history
        moves past the running system's `system.configurationRevision`.

        So a hand deploy from an unpushed commit, or from uncommitted work on
        the remote's tip, stays until the remote moves past it, while
        uncommitted work on an older commit is replaced once the remote moves
        on. A system built without a revision, such as a fresh install from an
        image, rebuilds at the first run.

        The check is the unit's `ExecCondition`: a skipped run shows as
        skipped, not failed, and the unit fails when the check cannot read the
        remote or fetch its history.
      '';
    };

    preRebuildHook = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Shell commands run as root before each rebuild, once the network is
        up. A failing command fails the run before anything is built.
      '';
    };

    postRebuildHook = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Shell commands run as root after a successful activation, before any
        reboot. A failing command fails the unit and skips the reboot, and the
        next run retries the same remote.
      '';
    };

    preRebootHook = lib.mkOption {
      type = lib.types.lines;
      default = "";
      internal = true;
      description = ''
        Shell commands run in a subshell before a reboot git-sync starts, set
        by ./drain-kubernetes-node.nix. A failure is logged and the reboot
        goes ahead.
      '';
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "nix-remote-rebuild";
      readOnly = true;
      internal = true;
      description = "The systemd StateDirectory, under /var/lib, that every git-sync unit shares.";
    };

    allowedSigners = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        SSH public keys allowed to sign the deployed commit with git's SSH
        signing. When the list is non-empty, a run refuses a locked revision
        that none of them signed, so push access to the remote alone cannot
        get root on the host. It also refuses a flake without a git revision,
        and a commit it cannot fetch.
      '';
      example = ["ssh-ed25519 AAAA..."];
    };

    sshKey = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        SSH private key the check and the rebuild use to fetch `git+ssh`
        flake inputs. Hosts it has not seen are trusted on first use
        (`StrictHostKeyChecking=accept-new`), so pin them in
        `programs.ssh.knownHosts`.
      '';
      example = "/root/.ssh/id_ed25519";
    };

    notifications = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Send desktop notifications to `notifyUser` when a run starts,
          succeeds, fails, refuses a commit, restores the previous system or
          leaves an update for the next boot. A reboot then waits 2 minutes,
          with a warning that says how to cancel it, instead of happening at
          once.
        '';
      };

      notifyUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = config.hostSpec.primaryUsername;
        description = ''
          User whose graphical session gets the notifications: the first of
          their sessions that `loginctl` lists. Required when
          `notifications.enable` is on.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.notifications.enable -> cfg.notifications.notifyUser != null;
        message = "nix.git-sync.notifications.notifyUser must be set when notifications are enabled";
      }
      {
        assertion = (cfg.interval != null) != (cfg.schedule != null);
        message = "nix.git-sync: exactly one of 'interval' or 'schedule' must be set";
      }
      {
        # A reboot after test boots the profile's old generation, discarding the update.
        assertion = cfg.reboot != "never" -> cfg.rebuildCommand != "test";
        message = "nix.git-sync: reboot = \"${cfg.reboot}\" needs rebuildCommand 'switch' or 'boot', not 'test'";
      }
    ];

    systemd = {
      services.nix-remote-rebuild = {
        description = "Automatic NixOS rebuild from remote flake";
        after = ["network-online.target"];
        wants = ["network-online.target"];

        # Prevent nixos-rebuild switch from killing this service mid-run
        restartIfChanged = false;
        stopIfChanged = false;

        environment = lib.optionalAttrs (cfg.sshKey != null) {
          GIT_SSH_COMMAND = "ssh -i ${cfg.sshKey} -o StrictHostKeyChecking=accept-new";
        };

        serviceConfig =
          {
            Type = "oneshot";
            StateDirectory = cfg.stateDirectory;
            ExecStart = rebuild;
          }
          // lib.optionalAttrs cfg.checkRemoteNewer {
            ExecCondition = checkNewer;
          };
      };

      timers.nix-remote-rebuild = {
        description = "Periodically rebuild NixOS from remote flake";
        wantedBy = ["timers.target"];
        timerConfig =
          {
            Unit = "nix-remote-rebuild.service";
            Persistent = true;
          }
          // (
            if cfg.schedule != null
            then {
              OnCalendar = cfg.schedule;
            }
            else {
              OnBootSec = "5min";
              OnUnitActiveSec = cfg.interval;
            }
          );
      };
    };
  };
}
