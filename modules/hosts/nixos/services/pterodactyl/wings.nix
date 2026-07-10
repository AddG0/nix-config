{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.pterodactyl.wings;
  yamlType = (pkgs.formats.yaml {}).type;

  generatedConfigFile =
    if cfg.settings != null
    then (pkgs.formats.yaml {}).generate "wings.yaml" cfg.settings
    else throw "services.pterodactyl.wings.settings must not be null";
in {
  options = {
    services.pterodactyl.wings = {
      enable = lib.mkEnableOption "Pterodactyl Wings";
      user = lib.mkOption {
        default = "pterodactyl";
        type = lib.types.str;
      };
      group = lib.mkOption {
        default = "pterodactyl";
        type = lib.types.str;
      };
      package = lib.mkOption {
        default = pkgs.nur.repos.xddxdd.pterodactyl-wings;
        defaultText = lib.literalExpression "pkgs.nur.repos.xddxdd.pterodactyl-wings";
        type = lib.types.package;
      };
      openFirewall = lib.mkOption {
        default = false;
        type = lib.types.bool;
      };
      hostName = lib.mkOption {
        default = null;
        type = lib.types.nullOr lib.types.str;
        example = "wings.example.com";
        description = "FQDN for the Wings nginx reverse-proxy vhost. Null → no vhost.";
      };
      acmeHost = lib.mkOption {
        default = null;
        type = lib.types.nullOr lib.types.str;
        description = "ACME certificate host for the Wings vhost.";
      };
      allocatedTCPPorts = lib.mkOption {
        default = [];
        type = lib.types.listOf lib.types.port;
      };
      allocatedUDPPorts = lib.mkOption {
        default = [];
        type = lib.types.listOf lib.types.port;
      };
      extraConfigFile = lib.mkOption {
        default = null;
        type = lib.types.nullOr lib.types.path;
      };
      settings = lib.mkOption {
        default = {};
        type = lib.types.nullOr (lib.types.submodule {
          freeformType = yamlType;
          options = {
            api = lib.mkOption {
              default = {};
              type = lib.types.nullOr (lib.types.submodule {
                freeformType = yamlType;
                options = {
                  host = lib.mkOption {
                    type = lib.types.str;
                    # Localhost: the API is reached only via the local nginx
                    # reverse proxy, never directly from the network.
                    default = "127.0.0.1";
                  };
                  port = lib.mkOption {
                    type = lib.types.port;
                    default = 443;
                  };
                  ssl = lib.mkOption {
                    default = {};
                    type = lib.types.nullOr (lib.types.submodule {
                      freeformType = yamlType;
                      options = {
                        enabled = lib.mkOption {
                          default = false;
                          type = lib.types.bool;
                        };
                        cert = lib.mkOption {
                          default = null;
                          type = lib.types.nullOr lib.types.str;
                        };
                        key = lib.mkOption {
                          default = null;
                          type = lib.types.nullOr lib.types.str;
                        };
                      };
                    });
                  };
                };
              });
            };
            system = lib.mkOption {
              default = {};
              type = lib.types.nullOr (lib.types.submodule {
                freeformType = yamlType;
                options = {
                  root_directory = lib.mkOption {
                    default = "/var/lib/pterodactyl";
                    type = lib.types.str;
                  };
                  username = lib.mkOption {
                    default = cfg.user;
                    type = lib.types.str;
                  };
                  sftp = lib.mkOption {
                    default = {};
                    type = lib.types.nullOr (lib.types.submodule {
                      freeformType = yamlType;
                      options = {
                        bind_address = lib.mkOption {
                          default = "0.0.0.0";
                          type = lib.types.str;
                        };
                        bind_port = lib.mkOption {
                          default = 2022;
                          type = lib.types.port;
                        };
                      };
                    });
                  };
                };
              });
            };
            ignore_panel_config_updates = lib.mkOption {
              default = true;
              type = lib.types.bool;
            };
          };
        });
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;
    users.groups."${cfg.group}".name = cfg.group;
    users.users.pterodactyl = {
      isSystemUser = true;
      inherit (cfg) group;
      extraGroups = ["docker"];
    };
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [cfg.settings.api.port cfg.settings.system.sftp.bind_port] ++ cfg.allocatedTCPPorts;
      allowedUDPPorts = cfg.allocatedUDPPorts;
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.settings.system.root_directory} 0770 ${cfg.user} ${cfg.group} -"
      "d /var/log/pterodactyl 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services = {
      "wings" = {
        after = ["network.target"];
        requires = ["docker.service"];
        wantedBy = ["multi-user.target"];
        partOf = ["docker.service"];
        startLimitBurst = 30;
        startLimitIntervalSec = 180;
        preStart = lib.mkMerge [
          (lib.mkIf (cfg.extraConfigFile != null) ''
            if [ ! -f "${cfg.settings.system.root_directory}/wings.yaml" ]; then
              ${pkgs.yq-go}/bin/yq ea '. as $item ireduce ({}; . * $item )' "${generatedConfigFile}" "${cfg.extraConfigFile}" > "${cfg.settings.system.root_directory}/wings.yaml"
            fi
          '')
          (lib.mkIf (cfg.extraConfigFile == null) ''
            if [ ! -f "${cfg.settings.system.root_directory}/wings.yaml" ]; then
              cp -L "${generatedConfigFile}" "${cfg.settings.system.root_directory}/wings.yaml"
            fi
          '')
          # We need this since the panel will update the url to 443 since we're most likely using nginx
          ''
            if [ -f "${cfg.settings.system.root_directory}/wings.yaml" ]; then
              echo "Ensuring Wings config is reset to port ${toString cfg.settings.api.port}"
              ${pkgs.yq-go}/bin/yq -i '.api.host = "${cfg.settings.api.host}"' "${cfg.settings.system.root_directory}/wings.yaml"
              ${pkgs.yq-go}/bin/yq -i '.api.port = ${toString cfg.settings.api.port}' "${cfg.settings.system.root_directory}/wings.yaml"
              ${pkgs.yq-go}/bin/yq -i '.api.ssl.enabled = false' "${cfg.settings.system.root_directory}/wings.yaml"
            fi
          ''
        ];
        serviceConfig = {
          User = "root";
          Group = cfg.group;
          LimitNOFILE = 4096;
          PIDFile = "/run/wings/daemon.pid";
          ExecStart = "${cfg.package}/bin/wings --config \"${cfg.settings.system.root_directory}/wings.yaml\"";
          Restart = "on-failure";
          RestartSec = "5s";
          SuccessExitStatus = "0 1 2";
        };
      };
    };

    # Reverse-proxy vhost lives in the module so hosts only set hostName/acmeHost.
    services.nginx.virtualHosts = lib.optionalAttrs (cfg.hostName != null) {
      ${cfg.hostName} = {
        forceSSL = true;
        useACMEHost = cfg.acmeHost;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.settings.api.port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
      };
    };

    networking.hosts = lib.optionalAttrs (cfg.hostName != null) {
      "127.0.0.1" = [cfg.hostName];
    };
  };
}
