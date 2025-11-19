{
  pkgs,
  config,
  nix-secrets,
  inputs,
  ...
}: let
  inherit (inputs) pterodactyl-addons;
in {
  services.pterodactyl.panel = {
    enable = true;
    ssl = true;
    blueprint = {
      enable = false;
      extensions = {
        "modpack-downloader" = {
          name = "modpack-downloader";
          version = "1.0.0";
          source = "${pterodactyl-addons}/modpack-installer.zip";
        };
      };
    };
    users = {
      primary = {
        email = config.hostSpec.email.user;
        inherit (config.hostSpec) username;
        firstName = config.hostSpec.username;
        lastName = "G";
        passwordFile = config.sops.secrets.pterodactylAdminPassword.path;
        isAdmin = true;
      };
    };
    locations = {
      uk = {
        short = "uk";
        long = "United Kingdom";
      };
    };
  };

  services.nginx = {
    virtualHosts."pterodactyl-local.${config.hostSpec.domain}" = {
      useACMEHost = config.hostSpec.domain;
      forceSSL = true;

      root = "${config.services.pterodactyl.panel.dataDir}/public";
      locations."/" = {
        index = "index.php";
        tryFiles = "$uri $uri/ /index.php?$query_string";
      };
      locations."~ \\.php$" = {
        extraConfig = ''
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_pass unix:/run/phpfpm/pterodactyl.sock;
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        '';
      };
    };
  };

  networking.hosts = {
    "127.0.0.1" = ["pterodactyl-local.${config.hostSpec.domain}"];
  };

  sops.secrets = {
    pterodactylAdminPassword = {
      sopsFile = "${nix-secrets}/secrets/pterodactyl/secrets.yaml";
      mode = "0400";
      owner = "root";
    };
    judePassword = {
      sopsFile = "${nix-secrets}/secrets/pterodactyl/users.yaml";
      mode = "0400";
      owner = "root";
    };
  };
}
