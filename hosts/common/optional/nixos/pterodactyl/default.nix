{pkgs, ...}: {
  imports = [
    ./wings.nix
    ./panel.nix
  ];
  # Basic system settings
  networking.firewall.allowedTCPPorts = [80 443 8080];
  services.openssh.enable = true;

  # PANEL CONFIGURATION
  services.pterodactyl.panel = {
    enable = true;
    domain = "panel.example.com";
    dataDir = "/var/www/pterodactyl";

    database = {
      host = "localhost";
      name = "pterodactyl";
      user = "pterodactyl";
      password = "super-secret-db-pass";
    };

    mail = {
      driver = "smtp";
      smtpHost = "smtp.mailprovider.com";
      smtpUser = "no-reply@example.com";
      smtpPass = "email-password";
      fromAddress = "no-reply@example.com";
      fromName = "My Game Panel";
    };
  };

  # WINGS CONFIGURATION
  services.pterodactyl.wings = {
    enable = true;
    panelUrl = "https://panel.example.com";
    nodeId = "node-uuid-here"; # provided by panel
    tokenId = "token-id-from-panel"; # also from panel
    token = "token-secret-from-panel";
    ssl = false; # Wings is on same host and behind Nginx — disable internal SSL
  };

  # OPTIONAL: Let NixOS set up a local database
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;

    ensureDatabases = ["pterodactyl"];

    ensureUsers = [
      {
        name = "pterodactyl";
        ensurePermissions = {
          "pterodactyl.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  systemd.services.set-pterodactyl-mysql-password = {
    description = "Set Pterodactyl MySQL user password";
    after = ["mysql.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "set-pterodactyl-pass" ''
              ${pkgs.mariadb}/bin/mysql -u root <<EOF
        ALTER USER 'pterodactyl'@'localhost' IDENTIFIED BY 'super-secret-db-pass';
        FLUSH PRIVILEGES;
        EOF
      '';
    };
  };

  # Enable Nginx & ACME SSL
  security.acme = {
    acceptTerms = true;
    defaults.email = "you@example.com";
  };

  services.nginx.enable = true;

  # Make sure Docker is enabled for Wings
  virtualisation.docker.enable = true;
}
