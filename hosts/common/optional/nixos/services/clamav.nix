{
  config,
  pkgs,
  lib,
  ...
}: let
  # Untrusted files land here; scanning all of /home never finishes.
  ingressDirs = ["Downloads" "MEGA downloads"];
  normalUserHomes =
    lib.mapAttrsToList (_username: user: user.home)
    (lib.filterAttrs (_username: user: user.isNormalUser) config.users.users);
  ingressPaths =
    lib.concatMap (home: map (dir: "${home}/${dir}") ingressDirs) normalUserHomes;

  # Where something that got in would install itself to survive a reboot.
  persistenceDirs = [
    ".config/autostart"
    ".config/systemd/user"
    ".local/bin"
    ".local/share/applications"
    "bin"
  ];
  persistencePaths =
    lib.concatMap (home: map (dir: "${home}/${dir}") persistenceDirs) normalUserHomes;

  # Don't add /tmp: its live sockets make clamdscan exit 2 and fail the unit.
  scanPaths = ingressPaths ++ persistencePaths;

  # clamdscan aborts on a missing argument, dropping the whole scan for one absent dir.
  clamdscan-present-only = pkgs.writeShellScript "clamdscan-present-only" ''
    paths=()
    for path in "$@"; do
      if [ -e "$path" ]; then
        paths+=("$path")
      else
        echo "skipping absent scan path: $path" >&2
      fi
    done

    if [ ''${#paths[@]} -eq 0 ]; then
      echo "no scan paths present; check services.clamav.scanner.scanDirectories" >&2
      exit 1
    fi

    exec ${config.services.clamav.package}/bin/clamdscan \
      --multiscan --fdpass --infected --allmatch "''${paths[@]}"
  '';

  notify-all-users = pkgs.writeShellScript "clamav-virus-event" ''
    ALERT="Signature detected by clamav: $CLAM_VIRUSEVENT_VIRUSNAME in $CLAM_VIRUSEVENT_FILENAME"

    # Journal first: a detection must be recorded even with no graphical session.
    ${pkgs.util-linux}/bin/logger -t clamav-virus-event -p daemon.crit "$ALERT"

    for ADDRESS in /run/user/*; do
        USERID=''${ADDRESS#/run/user/}
        /run/wrappers/bin/sudo -u "#$USERID" DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" \
          ${pkgs.libnotify}/bin/notify-send -u critical -i dialog-warning "Suspicious file" "$ALERT"
    done
  '';
in {
  security.sudo = {
    extraConfig = ''
      clamav ALL = (ALL) NOPASSWD: SETENV: ${pkgs.libnotify}/bin/notify-send
    '';
  };

  services = {
    clamav = {
      daemon = {
        enable = true;
        settings = {
          # ClamAV configuration. Refer to <https://linux.die.net/man/5/clamd.conf>, for details on supported values.

          # Notify-only: OnAccessPrevention blocks the write until the scan returns.
          OnAccessIncludePath = ingressPaths;
          OnAccessPrevention = false;
          OnAccessExcludeUname = "clamav";
          VirusEvent = "${notify-all-users}";
          User = "clamav";

          # Performance tuning
          MaxThreads = 10;
          MaxQueue = 30;
          ConcurrentDatabaseReload = true;

          # Scanning limits (prevent resource exhaustion)
          MaxScanSize = "500M";
          MaxFileSize = "150M";
          MaxRecursion = 20;
          MaxFiles = 15000;
          MaxEmbeddedPE = "50M";
          MaxHTMLNormalize = "50M";
          MaxScriptNormalize = "25M";
          StreamMaxLength = "500M";

          # Detection improvements
          Bytecode = true;
          BytecodeSecurity = "TrustSigned";
          BytecodeTimeout = 10000;
          HeuristicAlerts = true;
          HeuristicScanPrecedence = true;

          # Alert on suspicious content
          AlertEncrypted = true;
          AlertEncryptedArchive = true;
          AlertEncryptedDoc = true;
          AlertOLE2Macros = true;
          AlertPartitionIntersection = true;

          # Scan settings
          ScanPE = true;
          ScanELF = true;
          ScanOLE2 = true;
          ScanPDF = true;
          ScanSWF = true;
          ScanXMLDOCS = true;
          ScanHWP3 = true;
          ScanMail = true;
          ScanHTML = true;
          ScanArchive = true;
          PhishingSignatures = true;
          PhishingScanURLs = true;

          # Logging
          ExtendedDetectionInfo = true;
          LogTime = true;

          # Exclude paths that don't need scanning
          ExcludePath = [
            "^/proc"
            "^/sys"
            "^/dev"
            "^/run"
            "^/nix/store"
          ];
        };
      };
      # Runs as root -- fanotify requires it.
      clamonacc.enable = true;
      updater = {
        enable = true;
        interval = "daily";
      };
      # securiteinfo omitted deliberately: without a customer_id it fails the
      # whole refresh, sanesecurity and urlhaus included.
      fangfrisch = {
        enable = true;
        interval = "daily";
      };
      # Rescan: a file's signature may not have existed when it arrived.
      scanner = {
        enable = true;
        interval = "Tue *-*-* 04:00:00";
        scanDirectories = scanPaths;
      };
    };
  };

  # Upstream sets none of these; without it a timer due while the machine is
  # asleep is skipped outright rather than deferred.
  systemd.timers = {
    clamav-freshclam.timerConfig.Persistent = true;
    clamav-fangfrisch.timerConfig.Persistent = true;
    clamdscan.timerConfig.Persistent = true;
  };

  # --fdpass means clamd does the scanning for both clients, so the throttle
  # goes here; clamdscan only pays for the directory walk.
  systemd.services = {
    clamav-daemon.serviceConfig = {
      Nice = 10;
      CPUWeight = 20;
      IOWeight = 20;
    };

    clamdscan.serviceConfig = {
      # Upstream joins scanDirectories with bare spaces, splitting any path
      # containing one into two nonexistent arguments.
      ExecStart =
        lib.mkForce (lib.concatStringsSep " " ([clamdscan-present-only]
            ++ map (path: ''"${path}"'') scanPaths));

      Nice = 19;
      CPUWeight = 10;
      IOWeight = 10;
      IOSchedulingClass = "idle";
    };

    # freshclam is pulled in at boot by clamd, but network-online.target is
    # satisfied before the resolver answers, so the first run exits 11 on a DNS
    # failure. Let systemd retry rather than fail the unit: Type=exec so Restart
    # applies (oneshot forbids it), bounded so a genuinely-offline boot gives up
    # and leaves the refresh to the timer.
    clamav-freshclam = {
      startLimitIntervalSec = 300;
      startLimitBurst = 10;
      serviceConfig = {
        Type = lib.mkForce "exec";
        Restart = "on-failure";
        RestartSec = 15;
      };
    };
  };
}
