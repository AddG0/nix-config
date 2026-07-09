{
  lib,
  pkgs,
  php,
  cfg,
}: let
  appRoot = "${cfg.package}/share/php/pterodactyl-panel";
in
  pkgs.writeShellScript "pterodactyl-user-setup" ''
      set -e
      export APP_ENV_PATH="${cfg.stateDir}"
      export APP_STORAGE_PATH="${cfg.stateDir}/storage"
      cd ${appRoot}
      echo "[+] Creating Pterodactyl users..."

    ${
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (_name: userCfg: ''
          echo "[+] Creating ${userCfg.username}..."
          PASSWORD=$(cat ${userCfg.passwordFile} | tr -d '\r\n')

          if [ -z "$PASSWORD" ] || [ ${"\${#PASSWORD}"} -lt 8 ]; then
            echo "[!] Skipping ${userCfg.username} - password must be at least 8 characters"
          else
            env PASSWORD="$PASSWORD" ${pkgs.su}/bin/su --preserve-environment -s ${pkgs.bash}/bin/bash - ${cfg.user} -c '
              set +o history
              cd ${appRoot}
              ${php}/bin/php -d variables_order=EGPCS artisan p:user:make \
                --email="${userCfg.email}" \
                --username="${userCfg.username}" \
                --name-first="${userCfg.firstName}" \
                --name-last="${userCfg.lastName}" \
                --password="$PASSWORD" \
                --admin=${
            if userCfg.isAdmin
            then "1"
            else "0"
          } \
                --no-interaction
            ' || echo "[!] Skipping — user '${userCfg.username}' may already exist."
          fi

          unset PASSWORD
        '')
        cfg.users
      )
    }
  ''
