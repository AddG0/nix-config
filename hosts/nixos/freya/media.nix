{
  config,
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
    device = "//10.10.15.252/videos";
    fsType = "cifs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=60"
      "x-systemd.device-timeout=30s"
      "x-systemd.mount-timeout=30s"
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
      "echo_interval=10"
    ];
  };

  # /mnt/videos is a lazy automount (x-systemd.automount + noauto): triggered on
  # first access and resilient via cifs "soft" plus device-/mount-timeout=30s.
  # No reachability gate is used -- a previous wait-for-nas.service, coupled to
  # jellyfin (Before=multi-user.target), dragged the NAS check onto the
  # boot-critical path and stalled graphical.target for ~3min when the NAS was
  # down. Jellyfin reaches the share on demand through the automount instead.

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
