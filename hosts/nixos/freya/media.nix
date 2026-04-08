{
  config,
  nix-secrets,
  pkgs,
  ...
}: {
  sops.secrets = {
    "nas-credentials" = {
      sopsFile = "${nix-secrets}/users/${config.hostSpec.username}/nas-credentials.enc";
      format = "binary";
      neededForUsers = true;
    };
  };

  users.groups.media.gid = 984;

  users.users.${config.hostSpec.username}.extraGroups = ["media"];
  users.users.jellyfin.extraGroups = ["media"];

  fileSystems."/mnt/videos" = {
    device = "//10.10.15.252/videos";
    fsType = "cifs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=60"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
      "uid=${toString config.users.users.${config.hostSpec.username}.uid}"
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
