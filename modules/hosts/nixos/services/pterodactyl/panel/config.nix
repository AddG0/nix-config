{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.pterodactyl.panel;

  # Panel code is served read-only straight from the Nix store.
  appRoot = "${cfg.package}/share/php/pterodactyl-panel";

  # variables_order=EGPCS so $_ENV (read by bootstrap/app.php) is populated.
  artisan = "${php}/bin/php -d variables_order=EGPCS ${appRoot}/artisan";
  panelEnv = [
    "APP_ENV_PATH=${cfg.stateDir}"
    "APP_STORAGE_PATH=${cfg.stateDir}/storage"
  ];

  # Move reusable derivations into their own bindings
  php = cfg.phpPackage.withExtensions ({
    enabled,
    all,
  }:
    enabled
    ++ (with all; [
      bcmath
      curl
      gd
      mbstring
      mysqli
      tokenizer
      xml
      zip
      openssl
      pdo
      pdo_mysql
      posix
      simplexml
      session
      sodium
      fileinfo
      dom
      filter
    ]));

  userCreationScript = import ./user-setup.nix {inherit lib pkgs php cfg;};
  panelSetupScript = import ./panel-setup.nix {inherit pkgs php cfg;};
  locationSetupScript = import ./location-setup.nix {inherit pkgs lib cfg;};
in
  lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
    };

    users.groups.${cfg.group} = {};

    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [cfg.database.name];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensurePermissions = {
            "${cfg.database.name}.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    services.redis.servers."".enable = true;

    services.phpfpm.pools.pterodactyl = {
      inherit (cfg) user;
      inherit (cfg) group;
      phpPackage = php;
      # Load .env + storage from writable state, not the read-only store.
      # variables_order must include E so $_ENV (read by bootstrap/app.php) is
      # populated from these under FPM (CLI already defaults to it).
      phpEnv = {
        APP_ENV_PATH = "${cfg.stateDir}";
        APP_STORAGE_PATH = "${cfg.stateDir}/storage";
      };
      phpOptions = ''
        variables_order = "EGPCS"
      '';
      settings = {
        listen = "/run/phpfpm/pterodactyl.sock";
        "listen.owner" = cfg.user;
        "listen.group" = config.services.nginx.group;
        "listen.mode" = "0660";
        pm = "dynamic";
        "pm.max_children" = 50;
        "pm.start_servers" = 5;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 10;
      };
    };

    systemd.services.setup-pterodactyl-db = {
      description = "Setup Pterodactyl MySQL Database and User";
      after = ["mysql.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig.Type = "oneshot";
      script = ''
        set -e
        ${pkgs.mariadb}/bin/mysql <<EOF
        CREATE USER IF NOT EXISTS '${cfg.database.user}'@'${cfg.database.host}' IDENTIFIED VIA unix_socket;
        GRANT ALL PRIVILEGES ON ${cfg.database.name}.* TO '${cfg.database.user}'@'${cfg.database.host}';
        FLUSH PRIVILEGES;
        EOF
      '';
    };

    systemd.services.pterodactyl-panel-setup = {
      description = "Setup Pterodactyl Panel";
      after = ["network.target" "mysql.service" "setup-pterodactyl-db.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = "pterodactyl-panel";
        WorkingDirectory = appRoot;
        ExecStart = panelSetupScript;
      };
    };

    systemd.services.pterodactyl-panel-user-setup = {
      description = "Create Pterodactyl Admin Users";
      wantedBy = ["multi-user.target"];
      after = ["pterodactyl-panel-setup.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        WorkingDirectory = appRoot;
        ExecStart = userCreationScript;
      };
    };

    systemd.services.pterodactyl-panel-location-setup = {
      description = "Setup Pterodactyl Locations";
      wantedBy = ["multi-user.target"];
      after = ["pterodactyl-panel-setup.service"];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = appRoot;
        ExecStart = locationSetupScript;
      };
    };

    # Queue worker — Pterodactyl relies on it for emails, schedules, etc.
    systemd.services.pteroq = {
      description = "Pterodactyl Queue Worker";
      after = ["redis.service" "mysql.service" "pterodactyl-panel-setup.service"];
      requires = ["pterodactyl-panel-setup.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = appRoot;
        Environment = panelEnv;
        ExecStart = "${artisan} queue:work --queue=high,standard,low --sleep=3 --tries=3";
        Restart = "always";
        RestartSec = "5s";
      };
    };

    # Scheduler — the panel's cron entrypoint; must fire every minute.
    systemd.timers.pterodactyl-schedule = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "minutely";
        Unit = "pterodactyl-schedule.service";
      };
    };
    systemd.services.pterodactyl-schedule = {
      description = "Pterodactyl Scheduler";
      after = ["pterodactyl-panel-setup.service"];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = appRoot;
        Environment = panelEnv;
        ExecStart = "${artisan} schedule:run";
      };
    };

    # nginx vhost lives here (not per-host) so every host serves the store
    # package consistently; hosts only set hostName/acmeHost.
    services.nginx.virtualHosts = lib.optionalAttrs (cfg.hostName != null) {
      ${cfg.hostName} = {
        useACMEHost = cfg.acmeHost;
        forceSSL = cfg.ssl;
        root = "${appRoot}/public";
        locations."/" = {
          index = "index.php";
          tryFiles = "$uri $uri/ /index.php?$query_string";
        };
        locations."~ \\.php$".extraConfig = ''
          try_files $uri =404;
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_pass unix:/run/phpfpm/pterodactyl.sock;
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          # httpoxy mitigation (CVE-2016-5385): the panel makes outbound HTTP calls.
          fastcgi_param HTTP_PROXY "";
        '';
      };
    };

    networking.hosts = lib.optionalAttrs (cfg.hostName != null) {
      "127.0.0.1" = [cfg.hostName];
    };
  }
