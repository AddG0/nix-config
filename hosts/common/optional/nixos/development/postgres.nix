{
  pkgs,
  config,
  ...
}: let
  # Create local database(s) owned by `postgres`, so Flyway/JDBC can create
  # objects in the public schema (PG15+ revokes CREATE from PUBLIC; ownership
  # is what grants it). Connects via peer auth as the invoking superuser.
  pg-createdb = pkgs.writeShellApplication {
    name = "pg-createdb";
    runtimeInputs = with pkgs; [postgresql gnugrep];
    text = ''
      OWNER="postgres"

      if [ $# -eq 0 ]; then
        echo "Usage: pg-createdb <dbname> [dbname...]"
        echo "Creates PostgreSQL database(s) owned by '$OWNER'."
        exit 1
      fi

      for DB in "$@"; do
        if psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB';" | grep -q 1; then
          echo "Database '$DB' already exists — ensuring owner is '$OWNER'."
          psql -d postgres -c "ALTER DATABASE \"$DB\" OWNER TO \"$OWNER\";"
        else
          psql -d postgres -c "CREATE DATABASE \"$DB\" OWNER \"$OWNER\";"
          echo "Created database '$DB' owned by '$OWNER'."
        fi
      done
    '';
  };
in {
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql;
    ensureUsers = [
      {
        name = "${config.hostSpec.primaryUsername}";
        ensureClauses.superuser = true;
      }
    ];
    authentication = pkgs.lib.mkOverride 10 ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             postgres                                peer
      local   all             addg                                    peer
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
    '';
    settings = {
      shared_buffers = "256MB";
      effective_cache_size = "1GB";
      maintenance_work_mem = "64MB";
      work_mem = "4MB";
    };
  };

  environment.systemPackages = with pkgs; [
    pgcli
    pg-createdb
  ];

  # Backup configuration (optional)
  # services.postgresqlBackup = {
  #   enable = true;
  #   databases = [ "mydatabase" ];
  #   location = "/var/backup/postgresql";
  #   startAt = "*-*-* 03:00:00";
  # };
}
