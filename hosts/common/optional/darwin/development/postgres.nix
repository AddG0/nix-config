{
  pkgs,
  config,
  ...
}: {
  # PostgreSQL with high-performance configuration
  services.postgresql = {
    enable = true;
    enableTCPIP = true;

    # Use latest PostgreSQL version for best performance
    package = pkgs.postgresql_16;

    # Enable useful extensions
    extraPlugins = with pkgs.postgresql_16.pkgs; [
      postgis
      pg_repack
      pgvector
    ];

    # High-performance settings optimized for 128GB RAM
    settings = {
      # Memory settings - PostgreSQL can use more aggressive memory settings than MySQL
      shared_buffers = "32GB"; # 25% of RAM
      effective_cache_size = "96GB"; # 75% of RAM (OS + PG cache)
      work_mem = "256MB"; # Per-operation memory
      maintenance_work_mem = "8GB"; # For VACUUM, CREATE INDEX, etc.

      # WAL settings for performance
      wal_buffers = "64MB";
      wal_level = "replica";
      max_wal_size = "16GB";
      min_wal_size = "4GB";
      checkpoint_completion_target = 0.9;
      checkpoint_timeout = "15min";

      # Connection settings
      max_connections = 500;

      # Parallel query settings
      max_parallel_workers_per_gather = 8;
      max_parallel_workers = 32;
      max_parallel_maintenance_workers = 8;

      # Background writer settings
      bgwriter_delay = "50ms";
      bgwriter_lru_maxpages = 1000;
      bgwriter_lru_multiplier = 10.0;

      # Autovacuum settings for high-write workloads
      autovacuum_max_workers = 8;
      autovacuum_naptime = "10s";
      autovacuum_vacuum_cost_limit = 3000;

      # Query planner settings
      random_page_cost = 1.1; # Assume fast SSD storage
      seq_page_cost = 1.0;
      cpu_tuple_cost = 0.01;
      cpu_index_tuple_cost = 0.005;
      cpu_operator_cost = 0.0025;

      # Logging and monitoring
      log_statement = "none"; # Disable for performance
      log_duration = false;
      log_checkpoints = true;
      log_connections = false;
      log_disconnections = false;
      log_lock_waits = true;
      log_temp_files = 0; # Log all temp files

      # Performance monitoring
      track_activity_query_size = 4096;

      # JIT compilation for complex queries
      jit = true;
      jit_above_cost = 100000;
      jit_inline_above_cost = 500000;
      jit_optimize_above_cost = 500000;

      # Enable huge pages if available
      huge_pages = "try";

      # Synchronous commit for durability vs performance trade-off
      synchronous_commit = "on"; # Change to "off" for maximum speed

      # Full page writes (can disable for performance on reliable storage)
      full_page_writes = true; # Set to false for speed on good storage

      # Effective IO concurrency (must be 0 on macOS - lacks posix_fadvise)
      effective_io_concurrency = 0;
      maintenance_io_concurrency = 0;

      # Lock timeout
      lock_timeout = "30s";
      statement_timeout = 0; # No query timeout
      idle_in_transaction_session_timeout = "10min";
    };

    # Authentication configuration
    authentication = ''
      # Allow local connections
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
    '';
  };

  environment.systemPackages = with pkgs; [
    postgresql
  ];

  # Custom PostgreSQL initialization since nix-darwin doesn't support ensureUsers/initialScript
  launchd.user.agents.postgresql-init = {
    script = ''
      # Wait for PostgreSQL to be ready
      until ${pkgs.postgresql}/bin/pg_isready -h localhost -p 5432 > /dev/null 2>&1; do
        sleep 1
      done

      # Check if user already exists
      if ! ${pkgs.postgresql}/bin/psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${config.hostSpec.username}'" | grep -q 1; then
        # Create user role
        ${pkgs.postgresql}/bin/psql -U postgres -c "CREATE ROLE ${config.hostSpec.username} WITH LOGIN SUPERUSER;"

        # Create user database
        ${pkgs.postgresql}/bin/psql -U postgres -c "CREATE DATABASE ${config.hostSpec.username} OWNER ${config.hostSpec.username};"

        # Create additional databases if needed
        ${pkgs.postgresql}/bin/psql -U postgres -c "CREATE DATABASE IF NOT EXISTS shipperhq_dev;"
      fi
    '';
    serviceConfig.RunAtLoad = true;
    serviceConfig.KeepAlive = false;
    managedBy = "services.postgresql.enable";
  };
}
