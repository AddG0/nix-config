{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.pterodactyl.panel;
  user = "pterodactyl";
  group = "pterodactyl";
  dataDir = cfg.dataDir;
  php = pkgs.php.withExtensions (exts: [
    pkgs.php.extensions.bcmath
    pkgs.php.extensions.curl
    pkgs.php.extensions.gd
    pkgs.php.extensions.mbstring
    pkgs.php.extensions.mysqli
    pkgs.php.extensions.tokenizer
    pkgs.php.extensions.xml
    pkgs.php.extensions.zip
  ]);
  composer = pkgs.php.packages.composer.override {php = php;};
in {
  options.services.pterodactyl.panel = {
    enable = mkEnableOption "Enable Pterodactyl Panel (frontend)";
    domain = mkOption {
      type = types.str;
      description = "Domain for the panel";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/www/pterodactyl";
      description = "Panel data directory";
    };
    ssl = mkOption {
      type = types.bool;
      default = true;
      description = "Enable SSL";
    };
    database = {
      host = mkOption {
        type = types.str;
        default = "localhost";
      };
      name = mkOption {
        type = types.str;
        default = "pterodactyl";
      };
      user = mkOption {
        type = types.str;
        default = "pterodactyl";
      };
      password = mkOption {type = types.str;}; # secret
    };
    mail = {
      driver = mkOption {
        type = types.str;
        default = "smtp";
      }; # or mailgun, etc.
      smtpHost = mkOption {
        type = types.str;
        default = "smtp.example.com";
      };
      smtpUser = mkOption {type = types.str;};
      smtpPass = mkOption {type = types.str;};
      fromAddress = mkOption {
        type = types.str;
        default = "no-reply@example.com";
      };
      fromName = mkOption {
        type = types.str;
        default = "Game Panel";
      };
    };
  };

  config = mkIf cfg.enable {
    users.users.${user} = {
      isSystemUser = true;
      group = group;
      createHome = true;
      home = dataDir;
    };

    users.groups.${group} = {};

    services.phpfpm.pools.pterodactyl = {
      user = user;
      group = group;
      phpPackage = php;
      settings = {
        "listen.owner" = user;
        "listen.group" = group;
        "pm" = "dynamic";
        "pm.max_children" = 50;
        "pm.start_servers" = 5;
        "pm.min_spare_servers" = 5;
        "pm.max_spare_servers" = 35;
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain} = {
        enableACME = cfg.ssl;
        forceSSL = cfg.ssl;
        root = "${dataDir}/public";
        locations = {
          "/" = {
            index = "index.php";
            tryFiles = "$uri $uri/ /index.php?$query_string";
          };
          "~ \\.php$" = {
            extraConfig = ''
              include ${pkgs.nginx}/conf/fastcgi_params;
              fastcgi_pass unix:/run/phpfpm/pterodactyl.sock;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            '';
          };
        };
      };
    };

    systemd.services.pterodactyl-panel-setup = {
      description = "Initial setup for Pterodactyl Panel";
      after = ["network.target" "mysql.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        User = user;
        Group = group;
        WorkingDirectory = dataDir;
        ExecStart = ''
          ${pkgs.bash}/bin/bash -c "
            if [ ! -f 'composer.json' ]; then
              curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
              tar -xzvf panel.tar.gz --strip-components=1
              rm panel.tar.gz
              ${composer}/bin/composer install --no-dev --optimize-autoloader
              cp .env.example .env
              php artisan key:generate --force
              php artisan migrate --seed --force
              chown -R ${user}:${group} ${dataDir}
            fi
          "
        '';
      };
    };

    environment.systemPackages = [php composer pkgs.nodejs pkgs.yarn pkgs.nginx pkgs.mariadb];
  };
}
