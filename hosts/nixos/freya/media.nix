{
  config,
  lib,
  nix-secrets,
  pkgs,
  ...
}: {
  sops.secrets = {
    "nas-credentials" = {
      sopsFile = "${nix-secrets}/users/${config.hostSpec.primaryUsername}/nas-credentials.enc";
      format = "binary";
      neededForUsers = true;
    };
  };

  users.groups.media.gid = 984;

  users.users.${config.hostSpec.primaryUsername}.extraGroups = ["media"];
  users.users.jellyfin.extraGroups = ["media"];

  fileSystems."/mnt/videos" = {
    device = "//10.61.60.49/videos";
    fsType = "cifs";
    options = [
      "x-systemd.automount"
      "noauto"
      # No idle-timeout: keep the share mounted so playback never pays a WAN re-handshake.
      "x-systemd.device-timeout=30s"
      "x-systemd.mount-timeout=30s"
      "x-systemd.after=wait-for-nas.service"
      "x-systemd.requires=wait-for-nas.service"
      "uid=${toString config.users.users.${config.hostSpec.primaryUsername}.uid}"
      "forceuid"
      "gid=${toString config.users.groups.media.gid}"
      "forcegid"
      "file_mode=0640"
      "dir_mode=0750"
      "credentials=${config.sops.secrets.nas-credentials.path}"
      "_netdev"
      "soft"
      "vers=3.1.1"
      "cache=loose" # bypasses the cache=strict __readahead_batch kernel regression that stalls streaming/seeks.
      "actimeo=120"
      "nobrl" # skip byte-range locks players probe for -- avoids pointless WAN round-trips.
      "rsize=1048576" # 1 MiB, not the 4 MiB max: bigger requests stall longer on a lossy WAN.
      "wsize=1048576"
    ];
  };

  # network-online.target lies here: NetworkManager-wait-online is masked, so
  # jellyfin scans the share before wifi associates.
  # Pull this in from the mount only -- via jellyfin it inherits an implicit
  # Before=multi-user.target and lands on the boot path.
  systemd.services.wait-for-nas = {
    description = "Wait for NAS (10.61.60.49) to be reachable";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "wait-for-nas" ''
        log() { echo "$@"; }
        ${lib.custom.mkNetworkWaitScript {
          inherit pkgs;
          host = "10.61.60.49";
          maxAttempts = 20;
          waitSeconds = 1;
        }}
      '';
    };
  };

  services.jellyfin = {
    enable = true;
    # Use non-default port to avoid conflict with AWS VPN Client (which uses 8096 for OpenVPN management)
    network = {
      enable = true;
      httpPort = 41865;
      httpsPort = 41866;
    };
  };

  services.nginx.virtualHosts."jellyfin.${config.hostSpec.domain}" = {
    useACMEHost = config.hostSpec.domain;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:41865";
      proxyWebsockets = true;
    };
  };

  networking.hosts."127.0.0.1" = ["jellyfin.${config.hostSpec.domain}"];

  environment.systemPackages = with pkgs; [
    jellyfin-desktop
  ];
}
