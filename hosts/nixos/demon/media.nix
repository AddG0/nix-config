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
      "x-systemd.device-timeout=30s"
      "x-systemd.mount-timeout=30s"
      "x-systemd.after=wait-for-nas.service"
      "x-systemd.requires=wait-for-nas.service"
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

  # NetworkManager-wait-online "Finishes" before the Realtek r8169 driver has
  # bound enp12s0, so network-online.target lies. Poll the NAS directly to
  # gate consumers (and the mount) on real reachability.
  systemd.services.wait-for-nas = {
    description = "Wait for NAS (10.10.15.252) to be reachable";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "wait-for-nas" ''
        for i in $(seq 1 60); do
          if ${pkgs.iputils}/bin/ping -c 1 -W 1 10.10.15.252 >/dev/null 2>&1; then
            exit 0
          fi
          sleep 1
        done
        exit 1
      '';
    };
  };

  systemd.services.jellyfin = {
    after = ["wait-for-nas.service"];
    wants = ["wait-for-nas.service"];
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
