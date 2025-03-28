{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.pterodactyl.wings;
  user = "pterodactyl";
  group = "pterodactyl";
  configYaml = pkgs.formats.yaml {};
  settings = {
    debug = false;
    uuid = cfg.nodeId;
    token_id = cfg.tokenId;
    token = cfg.token;
    api = {
      host = cfg.host;
      port = cfg.port;
      ssl = {
        enabled = cfg.ssl;
        cert = cfg.sslCertPath or "";
        key = cfg.sslKeyPath or "";
      };
    };
    system = {
      username = user;
      data = cfg.dataDir;
      archive_directory = cfg.archiveDir;
      backup_directory = cfg.backupDir;
    };
    remote = {
      base_url = toString cfg.panelUrl;
    };
  };
  renderedConfig = configYaml.generate "wings.yml" settings;
  configFile = renderedConfig;
in {
  options.services.pterodactyl.wings = {
    enable = mkEnableOption "Enable Pterodactyl Wings daemon";
    panelUrl = mkOption {
      type = types.str;
      description = "Panel API URL";
    };
    tokenId = mkOption {
      type = types.str;
      description = "Wings token ID";
    };
    token = mkOption {
      type = types.str;
      description = "Wings token";
    }; # secret
    nodeId = mkOption {
      type = types.str;
      description = "Node ID";
    };
    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
    };
    port = mkOption {
      type = types.port;
      default = 8080;
    };
    ssl = mkOption {
      type = types.bool;
      default = true;
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/pterodactyl/volumes";
    };
    archiveDir = mkOption {
      type = types.path;
      default = "/var/lib/pterodactyl/archives";
    };
    backupDir = mkOption {
      type = types.path;
      default = "/var/lib/pterodactyl/backups";
    };
    sslCertPath = mkOption {
      type = types.str;
      default = "";
      description = "Path to the SSL cert for Wings API";
    };

    sslKeyPath = mkOption {
      type = types.str;
      default = "";
      description = "Path to the SSL key for Wings API";
    };
  };

  config = mkIf cfg.enable {
    users.users.${user} = {
      isSystemUser = true;
      createHome = true;
      home = lib.mkForce "/var/lib/pterodactyl";
      group = group;
      extraGroups = ["docker"];
    };

    users.groups.${group} = {};

    virtualisation.docker.enable = true;

    systemd.services.pterodactyl-wings = {
      description = "Pterodactyl Wings";
      after = ["docker.service"];
      requires = ["docker.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${pkgs.nur.repos.xddxdd.pterodactyl-wings}/bin/wings --config ${configFile}";
        User = user;
        Group = group;
        Restart = "on-failure";
        WorkingDirectory = "/var/lib/pterodactyl";
      };
    };

    environment.systemPackages = [pkgs.nur.repos.xddxdd.pterodactyl-wings];
  };
}
