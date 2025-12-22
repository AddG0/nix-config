#
# FIXME check for dependency somehow? Requires the msmtp.nix option for email notifications
#
{pkgs, ...}: let
  # FIXME
  # isEnabled = name: predicate: {
  # assertion = predicate;
  # message = "${name} should be enabled for the clamav.nix config to work correctly.";
  # };
  # Function to notify users and admin when a suspicious file is detected
  notify-all-users = pkgs.writeScript "notify-all-users-of-sus-file" ''
    ALERT="Signature detected by clamav: $CLAM_VIRUSEVENT_VIRUSNAME in $CLAM_VIRUSEVENT_FILENAME"
    # Send an alert to all graphical users.
    for ADDRESS in /run/user/*; do
        USERID=''${ADDRESS#/run/user/}
       /run/wrappers/bin/sudo -u "#$USERID" DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" ${pkgs.libnotify}/bin/notify-send -i dialog-warning "Suspicious file" "$ALERT"
    done

    echo -e "To:$(hostname).alerts.net@hexagon.cx\n\nSubject: Suspicious file on $(hostname)\n\n$ALERT" | msmtp -a default alerts.net@hexagon.cx
  '';
in {
  # FIXME
  # assertions = lib.mapAttrsToList isEnabled {
  # "hosts/common/optional/msmtp" = config.msmtp.enable;
  # };

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

          # On-access scanning
          OnAccessPrevention = false;
          OnAccessExtraScanning = true;
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
      updater = {
        enable = true;
        interval = "daily";
        frequency = 2;
        settings = {
          # Refer to <https://linux.die.net/man/5/freshclam.conf>,for details on supported values.
        };
      };
      # Additional signature databases (sanesecurity, urlhaus enabled by default)
      fangfrisch = {
        enable = true;
        interval = "daily";
        settings = {
          # SecuriteInfo adds 4M+ signatures (free tier is 30-day delayed)
          securiteinfo.enabled = true;
        };
      };
      # Scheduled filesystem scan
      scanner = {
        enable = true;
        interval = "*-*-* 04:00:00"; # 4 AM daily
        scanDirectories = [
          "/home"
          "/etc"
          "/var/lib"
          "/tmp"
          "/var/tmp"
        ];
      };
    };
  };
}
