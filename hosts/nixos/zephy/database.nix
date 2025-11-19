{pkgs, ...}: {
  # Enable MySQL service (MariaDB as the backend)
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;

    ensureDatabases = ["shipperhq_dev"];

    ensureUsers = [
      {
        name = "root";
        ensurePermissions = {
          "*.*" = "ALL PRIVILEGES";
        };
      }
    ];

    # Set admin password during initialization
    initialScript = pkgs.writeText "mysql-init.sql" ''
      -- Set admin user password using MariaDB-compatible syntax
      SET PASSWORD FOR 'root'@'localhost' = PASSWORD('root');

      -- Create root user for 127.0.0.1 access
      CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY 'root';
      GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;

      FLUSH PRIVILEGES;
    '';

    # Performance settings optimized for 128GB RAM machine
    settings = {
      mysqld = {
        # Memory settings - using ~40% of total RAM for buffer pool
        innodb_buffer_pool_size = "48G";
        innodb_log_file_size = "4G"; # Larger logs for better write performance
        innodb_log_buffer_size = "256M";

        # Connection settings
        max_connections = 1000;
        back_log = 500;

        # Thread settings for high concurrency
        innodb_read_io_threads = 16;
        innodb_write_io_threads = 16;
        innodb_purge_threads = 8;

        # Cache settings
        table_open_cache = 16000;
        table_definition_cache = 8000;
        thread_cache_size = 100;

        # Query cache (disabled - better for high write workloads)
        query_cache_type = 0;
        query_cache_size = 0;

        # Buffer settings
        sort_buffer_size = "8M";
        read_buffer_size = "8M";
        read_rnd_buffer_size = "16M";
        join_buffer_size = "8M";

        # Temp table settings
        tmp_table_size = "512M";
        max_heap_table_size = "512M";

        # Performance schema
        performance_schema = "ON";

        # InnoDB optimizations
        innodb_flush_method = "O_DIRECT_NO_FSYNC";
        innodb_doublewrite = 0; # Disable for speed (less safe)
        innodb_flush_log_at_trx_commit = 2; # Fast but less durable
        innodb_io_capacity = 10000;
        innodb_io_capacity_max = 20000;
        innodb_lru_scan_depth = 4000;

        # File per table for better performance
        innodb_file_per_table = 1;

        # Adaptive hash index
        innodb_adaptive_hash_index = "ON";
        innodb_adaptive_hash_index_parts = 16;

        # Compression
        innodb_compression_level = 6;
      };
    };
  };

  # PostgreSQL with high-performance configuration
  services.postgresql = {
    enable = true;
    enableTCPIP = true;

    # Use latest PostgreSQL version for best performance
    package = pkgs.postgresql_16;

    # Enable useful extensions
    extensions = with pkgs.postgresql_16.pkgs; [
      postgis
      pg_repack
      pgvector
    ];

    # Ensure databases exist
    ensureDatabases = ["shipperhq_dev"];

    # Ensure users exist
    ensureUsers = [
      {
        name = "addg";
        ensureClauses.superuser = true;
      }
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

      # Effective IO concurrency (set appropriately for NixOS/Linux)
      effective_io_concurrency = 200;
      maintenance_io_concurrency = 10;

      # Lock timeout
      lock_timeout = "30s";
      statement_timeout = 0; # No query timeout
      idle_in_transaction_session_timeout = "10min";
    };

    # Authentication configuration
    authentication = pkgs.lib.mkOverride 10 ''
      # Allow local connections
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
    '';
  };

  environment.systemPackages = with pkgs; [
    mysql84
    mycli
    postgresql
  ];
}
