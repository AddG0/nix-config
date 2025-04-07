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
        port = 8983;
      };
      remote = "http://${config.services.pterodactyl.panel.domain}";
    };
  };

  services.pterodactyl.panel = {
    enable = true;

    domain = "panel.local"; # or your actual domain
    ssl = false; # set to true if using ACME (Let's Encrypt)
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
      };
    };
    locations = {
      uk = {
        short = "uk";
        long = "United Kingdom";
      };
    };
  };

  networking.hosts = {
    "127.0.0.1" = ["panel.local"];
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

  security.firewall.allowedTCPPorts = [80 443 8983 2022 25565 25566];
}
