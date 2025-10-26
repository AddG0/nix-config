{
  config,
  pkgs,
  lib,
  ...
}: {
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;

    # Enable TCP/IP for local connections only
    enableTCPIP = true;

    # Data directory with secure permissions
    dataDir = "/var/lib/postgresql/16";

    # Secure authentication configuration
    authentication = pkgs.lib.mkOverride 10 ''
      # Local socket connections
      local   all             postgres                                peer
      local   all             n8n_user                                scram-sha-256
      local   all             readonly_user                           peer map=usermap
      local   all             all                                     peer map=usermap

      # TCP/IP connections for localhost only
      host    n8n_db          n8n_user        127.0.0.1/32            scram-sha-256
      host    n8n_db          n8n_user        ::1/128                 scram-sha-256

      # Reject all other network connections
      host    all             all             0.0.0.0/0               reject
      host    all             all             ::/0                    reject
    '';

    # Identity map for system users to database users
    identMap = ''
      # MAPNAME       SYSTEM-USERNAME         PG-USERNAME
      usermap         addg                    readonly_user
      usermap         addg                    postgres
      usermap         root                    postgres
      usermap         postgres                postgres
    '';

    # Secure PostgreSQL configuration
    settings = {
      # Port configuration
      port = 5432;

      # Memory and performance settings
      shared_buffers = "256MB";
      effective_cache_size = "1GB";
      maintenance_work_mem = "64MB";
      checkpoint_completion_target = 0.9;
      wal_buffers = "16MB";
      default_statistics_target = 100;
      random_page_cost = 1.1;
      effective_io_concurrency = 200;
      work_mem = "4MB";
      min_wal_size = "1GB";
      max_wal_size = "4GB";

      # Security settings
      ssl = "off"; # Local only, no need for SSL overhead
      password_encryption = "scram-sha-256";
      log_connections = true;
      log_disconnections = true;
      log_statement = "all";
      log_duration = true;
      log_line_prefix = "%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ";

      # Enhanced logging for security monitoring
      log_min_duration_statement = 0; # Log all statements
      log_checkpoints = true;
      log_lock_waits = true;
      log_temp_files = 0;
      log_autovacuum_min_duration = 0;

      # Connection limits
      max_connections = 20; # Conservative limit for local use
      superuser_reserved_connections = 3;

      # Timeout settings
      statement_timeout = "30s";
      lock_timeout = "10s";
      idle_in_transaction_session_timeout = "60s";

      # WAL and checkpoint settings for data integrity
      wal_level = "replica";
      archive_mode = "on";
      archive_command = "test ! -f /var/lib/postgresql/archive/%f && cp %p /var/lib/postgresql/archive/%f";
      max_wal_senders = 0; # No replication needed for local setup

      # Data integrity
      fsync = true;
      synchronous_commit = "on";
      full_page_writes = true;

      # Prevent data corruption
      restart_after_crash = true;

      # Resource limits
      temp_file_limit = "1GB";

      # Security hardening
      log_statement_stats = false;
      log_parser_stats = false;
      log_planner_stats = false;
      log_executor_stats = false;
    };

    # Initial databases and users
    initialScript = pkgs.writeText "backend-initScript" ''
      -- Create n8n database
      CREATE DATABASE n8n_db;

      -- Create n8n user (requires password for authentication)
      CREATE USER n8n_user;
      -- Password must be set manually after deployment:
      -- ALTER USER n8n_user PASSWORD 'your_secure_password';

      -- Grant minimal required privileges to n8n user
      GRANT CONNECT ON DATABASE n8n_db TO n8n_user;
      GRANT USAGE ON SCHEMA public TO n8n_user;
      GRANT CREATE ON SCHEMA public TO n8n_user;
      GRANT ALL PRIVILEGES ON DATABASE n8n_db TO n8n_user;

      -- Create read-only user for monitoring/backup (uses peer authentication)
      CREATE USER readonly_user;
      GRANT CONNECT ON DATABASE n8n_db TO readonly_user;
      GRANT USAGE ON SCHEMA public TO readonly_user;
      GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;

      -- Revoke default public schema privileges
      REVOKE CREATE ON SCHEMA public FROM PUBLIC;
      REVOKE ALL ON DATABASE postgres FROM PUBLIC;
      REVOKE ALL ON DATABASE template1 FROM PUBLIC;
    '';
  };

  # Ensure PostgreSQL starts after network is ready
  systemd.services.postgresql = {
    wants = ["network-online.target"];
    after = ["network-online.target"];

    # Service hardening
    serviceConfig = {
      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictRealtime = true;
      RestrictNamespaces = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      SystemCallFilter = ["@system-service" "~@privileged" "~@resources"];

      # File system permissions
      ReadWritePaths = ["/var/lib/postgresql"];
      ReadOnlyPaths = ["/nix/store"];

      # User and group isolation
      DynamicUser = false; # PostgreSQL needs consistent UID
      User = "postgres";
      Group = "postgres";

      # Restart policy
      Restart = "always";
      RestartSec = "10s";
    };
  };

  # Create archive directory for WAL files
  systemd.tmpfiles.rules = [
    "d /var/lib/postgresql/archive 0750 postgres postgres -"
    "d /var/lib/postgresql/backups 0750 postgres postgres -"
  ];

  # Automated backup service
  systemd.services.postgresql-backup = {
    description = "PostgreSQL database backup";
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";
      ExecStart = pkgs.writeShellScript "postgres-backup" ''
        set -euo pipefail

        BACKUP_DIR="/var/lib/postgresql/backups"
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)

        # Create compressed backup with checksums
        ${pkgs.postgresql_16}/bin/pg_dumpall \
          --clean \
          --if-exists \
          --verbose \
          | ${pkgs.gzip}/bin/gzip -9 > "$BACKUP_DIR/full_backup_$TIMESTAMP.sql.gz"

        # Verify backup integrity
        ${pkgs.gzip}/bin/gunzip -t "$BACKUP_DIR/full_backup_$TIMESTAMP.sql.gz"

        # Remove backups older than 30 days
        find "$BACKUP_DIR" -name "full_backup_*.sql.gz" -mtime +30 -delete

        echo "Backup completed: full_backup_$TIMESTAMP.sql.gz"
      '';
    };

    # Run backup daily at 2 AM
    startAt = "02:00";

    # Ensure PostgreSQL is running
    wants = ["postgresql.service"];
    after = ["postgresql.service"];
  };

  # Enable backup timer
  systemd.timers.postgresql-backup.enable = true;

  # Log rotation for PostgreSQL logs
  services.logrotate = {
    enable = true;
    settings = {
      "/var/lib/postgresql/16/log/postgresql-*.log" = {
        frequency = "daily";
        rotate = 30;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
        create = "640 postgres postgres";
        postrotate = "systemctl reload postgresql.service";
      };
    };
  };

  # Firewall configuration - block all external access
  networking.firewall = {
    # Explicitly block PostgreSQL port from external access
    extraCommands = ''
      # Block PostgreSQL port from external networks
      iptables -A INPUT -p tcp --dport 5432 -s 127.0.0.1 -j ACCEPT
      iptables -A INPUT -p tcp --dport 5432 -j DROP
    '';
  };

  # System monitoring for PostgreSQL
  services.prometheus = {
    exporters = {
      postgres = {
        enable = true;
        dataSourceName = "postgresql:///postgres?host=/run/postgresql&user=postgres&sslmode=disable";
        runAsLocalSuperUser = true;
      };
    };
  };
}
