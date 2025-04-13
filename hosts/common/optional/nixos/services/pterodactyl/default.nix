{
  pkgs,
  config,
  nix-secrets,
  ...
}: {
  services.pterodactyl.wings = {
    enable = true;
    settings = {
      api = {
        ssl.enabled = false;
        port = 8080;
      };
      remote = "wings-eu.addg0.com";
    };
  };

  services.nginx.virtualHosts."wings-eu.addg0.com" = {
    forceSSL = true;
    useACMEHost = "addg0.com";

    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
      '';
    };
  };

  services.pterodactyl.panel = {
    enable = true;
    ssl = true;
    users = {
      primary = {
        email = config.hostSpec.email.user;
        username = config.hostSpec.username;
        firstName = config.hostSpec.username;
        lastName = "G";
        passwordFile = config.sops.secrets.pterodactylAdminPassword.path;
        isAdmin = true;
      };
      jude = {
        inherit (nix-secrets.pterodactyl.users.jude) email username firstName lastName;
        passwordFile = config.sops.secrets.judePassword.path;
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
    virtualHosts."pterodactyl-eu.addg0.com" = {
      useACMEHost = "addg0.com";
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
    "127.0.0.1" = ["pterodactyl-eu.addg0.com" "wings-eu.addg0.com"];
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

  security.firewall.allowedTCPPorts = [80 443 8983 2022 25565 25566 24454 24455 24456];
}
