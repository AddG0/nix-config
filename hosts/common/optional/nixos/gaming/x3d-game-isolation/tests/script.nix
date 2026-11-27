# Game isolation's scripts against fake systemd, gamemode, pgrep and sudo, the watcher also on fixture /proc and cgroup trees; cases in the .bats files.
{
  harness,
  pkgs,
  lib,
  ...
}: let
  # Logs each call to $CALLS and fails any naming $SYSTEMCTL_FAIL_UNIT; under $CGROUP_ROOT it writes AllowedCPUs to the unit's cpuset.cpus as systemd does, unless $SYSTEMCTL_NO_APPLY (cpuset not delegated).
  fakeSystemctl = pkgs.writeShellScriptBin "systemctl" ''
    echo "systemctl $*" >>"$CALLS"
    base=''${CGROUP_ROOT:-}
    for arg in "$@"; do
      [ "$arg" != "''${SYSTEMCTL_FAIL_UNIT:-}" ] || exit 1
      case $arg in
        --user) base=$base$USER_MANAGER_CGROUP ;;
        AllowedCPUs=*) cpus=''${arg#AllowedCPUs=} ;;
        set-property | --runtime) ;;
        *) unit=$arg ;;
      esac
    done
    [ -z "''${SYSTEMCTL_NO_APPLY:-}" ] || exit 0
    if [ -n "''${CGROUP_ROOT:-}" ] && [ -n "''${unit:-}" ] && [ -d "$base/$unit" ]; then printf '%s' "''${cpus:-}" >"$base/$unit/cpuset.cpus"; fi
  '';
  # Logs each call to $CALLS, rejects the first $BUSCTL_FAIL_TIMES like a move naming an exited PID, and adds the PIDs to the new scope under $USER_MANAGER_CGROUP (slices nested by name, as systemd does) unless $BUSCTL_NO_MOVE.
  fakeBusctl = pkgs.writeShellScriptBin "busctl" ''
    echo "busctl $*" >>"$CALLS"
    if [ "$(grep -c '^busctl' "$CALLS")" -le "''${BUSCTL_FAIL_TIMES:-0}" ]; then
      echo "Call failed: Failed to set unit properties: No such process" >&2
      exit 1
    fi
    [ -z "''${BUSCTL_NO_MOVE:-}" ] || exit 0
    args=("$@")
    for i in "''${!args[@]}"; do
      case "''${args[$i]}" in
        StartTransientUnit) unit=''${args[$((i + 2))]} ;;
        Slice) slice=''${args[$((i + 2))]} ;;
        PIDs) pids=("''${args[@]:$((i + 3)):''${args[$((i + 2))]}}") ;;
      esac
    done
    target=$USER_MANAGER_CGROUP
    prefix=""
    IFS=- read -ra parts <<<"''${slice%.slice}"
    for part in "''${parts[@]}"; do
      prefix+="''${prefix:+-}$part"
      target+="/$prefix.slice"
    done
    mkdir -p "$CGROUP_ROOT$target/$unit"
    for pid in "''${pids[@]}"; do
      echo "0::$target/$unit" >"$PROC_ROOT/$pid/cgroup"
      echo "$pid" >>"$CGROUP_ROOT$target/$unit/cgroup.procs"
    done
  '';
  fakeSystemd = pkgs.symlinkJoin {
    name = "fake-systemd";
    paths = [fakeSystemctl fakeBusctl];
  };

  # gdbus answers ListGames with $GAMES_LISTING (default no game), noting each call in $GDBUS_LOG; `monitor` prints $MONITOR_EVENTS, holds the stream open $MONITOR_HOLD seconds, then ends it.
  fakeGlib = pkgs.writeShellScriptBin "gdbus" ''
    if [ "$1" = monitor ]; then
      printf '%s' "''${MONITOR_EVENTS:-}"
      sleep "''${MONITOR_HOLD:-0}"
      exit 0
    fi
    [ -z "''${GDBUS_LOG:-}" ] || echo ListGames >>"$GDBUS_LOG"
    printf '%s\n' "''${GAMES_LISTING:-(@a(io) [],)}"
  '';

  # pgrep finds the Steam client at $STEAM_PID, or nothing.
  fakeProcps = pkgs.writeShellScriptBin "pgrep" ''
    [ -n "''${STEAM_PID:-}" ] || exit 1
    echo "$STEAM_PID"
  '';

  # sudo logs the command and exits $SUDO_EXIT; on success it acts out the helper on the fixture: system services fenced to every CPU but the game's, the V-Cache split.
  fakeSudo = pkgs.writeShellScript "sudo" ''
    source ${../cpu-lists.bash}
    echo "sudo $*" >>"$CALLS"
    [ -z "''${SUDO_EXIT:-}" ] || exit "$SUDO_EXIT"
    mkdir -p "$CGROUP_ROOT/system.slice" "$CGROUP_ROOT/init.scope"
    case $3 in
      split)
        rest=$(without_cpus 0-7 "$4")
        printf '%s' "$rest" >"$CGROUP_ROOT/system.slice/cpuset.cpus"
        printf '%s' "$rest" >"$CGROUP_ROOT/init.scope/cpuset.cpus"
        echo "L3:0=f;1=ffff" >"$RESCTRL_ROOT/schemata"
        ;;
      release)
        : >"$CGROUP_ROOT/system.slice/cpuset.cpus"
        : >"$CGROUP_ROOT/init.scope/cpuset.cpus"
        echo "L3:0=ffff;1=ffff" >"$RESCTRL_ROOT/schemata"
        ;;
    esac
  '';

  # mountpoint answers whether resctrl is mounted with $MOUNTED_EXIT (default yes); mount and taskset log to $CALLS.
  fakeUtilLinux = pkgs.symlinkJoin {
    name = "fake-util-linux";
    paths = [
      (pkgs.writeShellScriptBin "mountpoint" ''exit "''${MOUNTED_EXIT:-0}"'')
      (pkgs.writeShellScriptBin "mount" ''echo "mount $*" >>"$CALLS"'')
      (pkgs.writeShellScriptBin "taskset" ''echo "taskset $*" >>"$CALLS"'')
    ];
  };

  # The CPU split $CCD_SPLIT, or exit $CCD_EXIT (3: no cache CCD).
  fakeCacheCcd = pkgs.writeShellScript "x3d-cache-ccd" ''
    [ -z "''${CCD_EXIT:-}" ] || exit "$CCD_EXIT"
    echo "''${CCD_SPLIT:-0-1,4-5 2-3,6-7}"
  '';

  fakedPkgs =
    pkgs
    // {
      systemd = fakeSystemd;
      glib = fakeGlib;
      procps = fakeProcps;
      util-linux = fakeUtilLinux;
    };
  script = path: args: lib.getExe (lib.callPackageWith fakedPkgs path args);
  fixtureRoots = {
    procRoot = "$PROC_ROOT";
    cgroupRoot = "$CGROUP_ROOT";
    cpuRoot = "$CPU_ROOT";
    resctrlRoot = "$RESCTRL_ROOT";
  };
in
  harness.bats "x3d-game-isolation" [./cache-ccd.bats ./isolate.bats ./watcher.bats] {
    cacheCcd = lib.getExe (pkgs.callPackage ../cache-ccd.nix {});
    isolate = script ../isolate.nix {
      cacheCcd = fakeCacheCcd;
      cpuRoot = "$CPU_ROOT";
      resctrlRoot = "$RESCTRL_ROOT";
      group = "$RESCTRL_GROUP";
    };
    watcher = script ../watcher.nix ({
        cacheCcd = fakeCacheCcd;
        isolate = "isolate";
        sudo = fakeSudo;
        minCores = 1;
        retryPendingAfter = 1;
        retryFailedAfter = 1;
        sizeEvery = 1;
        sizeWindow = 1;
      }
      // fixtureRoots);
  }
