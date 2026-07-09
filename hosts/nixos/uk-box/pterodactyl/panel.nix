{
  config,
  inputs,
  nix-secrets,
  ...
}: {
  services.pterodactyl.panel = {
    enable = true;
    ssl = true;
    hostName = "pterodactyl-eu.${config.hostSpec.domain}";
    acmeHost = config.hostSpec.domain;
    url = "https://pterodactyl-eu.${config.hostSpec.domain}";
    appKeyFile = config.sops.secrets.pterodactylAppKey.path;

    addons = [
      {
        name = "materialui";
        source = "${inputs.pterodactyl-addons}/themes/MaterialUI Theme.zip";
        # Theme ships prebuilt assets + ThemeController; the AssetComposer
        # replacement + admin route block it documents are vendored alongside.
        install = ''
          tmp=$(mktemp -d)
          unzip -q "$src" -d "$tmp"
          theme="$tmp/MaterialUI Theme"

          cp -rf "$theme/public/assets/." public/assets/
          install -Dm644 "$theme/app/Http/Controllers/Admin/ThemeController.php" \
            app/Http/Controllers/Admin/ThemeController.php
          cp ${./materialui-AssetComposer.php} app/Http/ViewComposers/AssetComposer.php
          printf '\n' >> routes/admin.php
          cat ${./materialui-admin-routes.php} >> routes/admin.php
        '';
      }
    ];

    users = {
      primary = {
        email = config.hostSpec.email.user;
        username = config.hostSpec.primaryUsername;
        firstName = config.hostSpec.primaryUsername;
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

  sops.secrets = {
    pterodactylAdminPassword = {
      sopsFile = "${nix-secrets}/services/pterodactyl/uk-box.yaml";
      key = "users/admin/password";
      mode = "0400";
      owner = "root";
    };
    pterodactylAppKey = {
      sopsFile = "${nix-secrets}/services/pterodactyl/uk-box.yaml";
      key = "panel/app_key";
      mode = "0400";
      owner = config.services.pterodactyl.panel.user;
    };
    judePassword = {
      sopsFile = "${nix-secrets}/services/pterodactyl/uk-box.yaml";
      key = "users/jude/password";
      mode = "0400";
      owner = "root";
    };
  };
}
