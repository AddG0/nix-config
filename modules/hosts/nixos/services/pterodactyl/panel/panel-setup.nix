{
  pkgs,
  php,
  cfg,
}: let
  appRoot = "${cfg.package}/share/php/pterodactyl-panel";

  # Non-secret config, rendered declaratively. APP_KEY is appended at runtime
  # so the secret never enters the Nix store. APP_*_CACHE relocate Laravel's
  # compiled caches off the read-only store into writable state.
  envTemplate = pkgs.writeText "pterodactyl-env" ''
    APP_ENV=production
    APP_DEBUG=false
    APP_TIMEZONE=UTC
    APP_URL=${cfg.url}
    APP_LOCALE=en
    APP_ENVIRONMENT_ONLY=false
    APP_SERVICE_AUTHOR=noreply@pterodactyl.io
    LOG_CHANNEL=daily
    LOG_LEVEL=info

    DB_CONNECTION=mysql
    DB_HOST=${cfg.database.host}
    DB_PORT=3306
    DB_DATABASE=${cfg.database.name}
    DB_USERNAME=${cfg.database.user}
    DB_PASSWORD=

    CACHE_DRIVER=file
    SESSION_DRIVER=file
    QUEUE_CONNECTION=redis
    REDIS_HOST=127.0.0.1
    REDIS_PORT=6379
    REDIS_PASSWORD=

    MAIL_MAILER=log

    APP_CONFIG_CACHE=${cfg.stateDir}/cache/config.php
    APP_ROUTES_CACHE=${cfg.stateDir}/cache/routes.php
    APP_EVENTS_CACHE=${cfg.stateDir}/cache/events.php
    APP_PACKAGES_CACHE=${cfg.stateDir}/cache/packages.php
    APP_SERVICES_CACHE=${cfg.stateDir}/cache/services.php
  '';

  artisan = "${php}/bin/php -d variables_order=EGPCS ${appRoot}/artisan";
in
  pkgs.writeShellScript "pterodactyl-panel-setup" ''
    set -euo pipefail

    STATE="${cfg.stateDir}"
    # Read-only store code loads its env/storage from writable state (see the
    # APP_ENV_PATH / APP_STORAGE_PATH hooks in bootstrap/app.php).
    export APP_ENV_PATH="$STATE"
    export APP_STORAGE_PATH="$STATE/storage"

    echo "[+] Ensuring writable state layout in $STATE..."
    mkdir -p \
      "$STATE/storage/app/public" \
      "$STATE/storage/framework/cache" \
      "$STATE/storage/framework/sessions" \
      "$STATE/storage/framework/views" \
      "$STATE/storage/logs" \
      "$STATE/cache"

    # APP_KEY: prefer the provided secret file; otherwise generate and persist.
    ${
      if cfg.appKeyFile != null
      then ''APP_KEY="$(tr -d '\r\n' < ${cfg.appKeyFile})"''
      else ''
        if [ ! -f "$STATE/.app_key" ]; then
          ( umask 077; echo "base64:$(head -c 32 /dev/urandom | base64)" > "$STATE/.app_key" )
        fi
        APP_KEY="$(cat "$STATE/.app_key")"
      ''
    }

    echo "[+] Rendering $STATE/.env..."
    ( umask 077
      cat ${envTemplate} > "$STATE/.env.tmp"
      echo "APP_KEY=$APP_KEY" >> "$STATE/.env.tmp"
      mv "$STATE/.env.tmp" "$STATE/.env"
    )

    # Migrate only when the deployed package (version or addons) actually
    # changes, backing up the DB first as a safety net (kept to the last 10).
    STORE_MARKER="$STATE/.deployed-store-path"
    if [ "$(cat "$STORE_MARKER" 2>/dev/null || true)" != "${cfg.package}" ]; then
      if ${pkgs.mariadb}/bin/mysql -N -e "SELECT 1 FROM information_schema.tables WHERE table_schema='${cfg.database.name}' AND table_name='migrations' LIMIT 1;" 2>/dev/null | grep -q 1; then
        mkdir -p "$STATE/backups"
        echo "[+] Backing up database before migrate..."
        ${pkgs.mariadb}/bin/mysqldump ${cfg.database.name} > "$STATE/backups/panel-$(date +%Y%m%d-%H%M%S).sql" \
          || echo "[!] database backup failed (continuing)"
        ls -1t "$STATE"/backups/panel-*.sql 2>/dev/null | tail -n +11 | xargs -r rm -f
      fi
      echo "[+] Running migrations..."
      ${artisan} migrate --seed --force
      echo "${cfg.package}" > "$STORE_MARKER"
    fi

    # No config:cache — env() must resolve at runtime; just drop stale caches.
    ${artisan} config:clear
    ${artisan} view:clear
    echo "[+] Panel ${cfg.package.version} ready (code served read-only from the store)."
  ''
