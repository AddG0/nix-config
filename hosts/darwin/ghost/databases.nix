{pkgs, config, ...}: {
  # Enable MySQL service (MariaDB as the backend)
  services.mysql = {
    enable = true;

    # NixOS-style configuration
    ensureDatabases = [ "shipperhq_dev" ];

    # Create an admin user with full privileges
    ensureUsers = [
      {
        name = "root";
        authentication = "password";  # Use password authentication instead of socket
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
        innodb_buffer_pool_instances = 48;  # 1GB per instance for better concurrency
        innodb_log_file_size = "4G";  # Larger logs for better write performance
        innodb_log_buffer_size = "256M";

        # Connection settings
        max_connections = 1000;
        back_log = 500;

        # Thread settings for high concurrency
        innodb_thread_concurrency = 0;  # Let InnoDB manage
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
        innodb_doublewrite = 0;  # Disable for speed (less safe)
        innodb_flush_log_at_trx_commit = 2;  # Fast but less durable
        innodb_io_capacity = 10000;
        innodb_io_capacity_max = 20000;
        innodb_lru_scan_depth = 4000;
        innodb_page_cleaners = 8;

        # File per table for better performance
        innodb_file_per_table = 1;

        # Adaptive hash index
        innodb_adaptive_hash_index = "ON";
        innodb_adaptive_hash_index_parts = 16;

        # Change buffer for faster inserts
        innodb_change_buffer_max_size = 50;

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
    extraPlugins = with pkgs.postgresql_16.pkgs; [
      postgis
      pg_repack
      pgvector
    ];

    # High-performance settings optimized for 128GB RAM
    settings = {
      # Memory settings - PostgreSQL can use more aggressive memory settings than MySQL
      shared_buffers = "32GB";              # 25% of RAM
      effective_cache_size = "96GB";        # 75% of RAM (OS + PG cache)
      work_mem = "256MB";                   # Per-operation memory
      maintenance_work_mem = "8GB";         # For VACUUM, CREATE INDEX, etc.

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
      random_page_cost = 1.1;              # Assume fast SSD storage
      seq_page_cost = 1.0;
      cpu_tuple_cost = 0.01;
      cpu_index_tuple_cost = 0.005;
      cpu_operator_cost = 0.0025;

      # Logging and monitoring
      log_statement = "none";               # Disable for performance
      log_duration = false;
      log_checkpoints = true;
      log_connections = false;
      log_disconnections = false;
      log_lock_waits = true;
      log_temp_files = 0;                   # Log all temp files

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
      synchronous_commit = "on";            # Change to "off" for maximum speed

      # Full page writes (can disable for performance on reliable storage)
      full_page_writes = true;              # Set to false for speed on good storage

      # Effective IO concurrency (must be 0 on macOS - lacks posix_fadvise)
      effective_io_concurrency = 0;
      maintenance_io_concurrency = 0;

      # Lock timeout
      lock_timeout = "30s";
      statement_timeout = 0;                # No query timeout
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

  # Redis with high-performance configuration
  services.redis = {
    enable = true;

    # Bind to localhost for security
    bind = "127.0.0.1";

    # Port configuration
    port = 6379;

    # Disable AOF for maximum performance (data not persisted)
    appendOnly = false;

    # High-performance settings via extraConfig
    extraConfig = ''
      # Memory settings
      maxmemory 16gb
      maxmemory-policy allkeys-lru

      # Persistence settings for performance
      save ""
      stop-writes-on-bgsave-error no
      rdbcompression no
      rdbchecksum no

      # Performance tuning
      tcp-backlog 511
      timeout 0
      tcp-keepalive 300

      # Threading and I/O (Redis 6.0+)
      io-threads 8
      io-threads-do-reads yes

      # Memory optimizations
      activerehashing yes
      hz 50
      dynamic-hz yes

      # Client output buffer limits
      client-output-buffer-limit normal 0 0 0
      client-output-buffer-limit replica 256mb 64mb 60
      client-output-buffer-limit pubsub 32mb 8mb 60

      # Lazy freeing for performance
      lazyfree-lazy-eviction yes
      lazyfree-lazy-expire yes
      lazyfree-lazy-server-del yes
      replica-lazy-flush yes

      # Network settings
      tcp-nodelay yes

      # Logging
      loglevel notice
      syslog-enabled no

      # Slow log
      slowlog-log-slower-than 10000
      slowlog-max-len 128

      # Advanced config
      hash-max-ziplist-entries 512
      hash-max-ziplist-value 64
      list-max-ziplist-size -2
      list-compress-depth 0
      set-max-intset-entries 512
      zset-max-ziplist-entries 128
      zset-max-ziplist-value 64
      hll-sparse-max-bytes 3000
      stream-node-max-bytes 4096
      stream-node-max-entries 100

      # Active defragmentation
      activedefrag yes
      active-defrag-ignore-bytes 100mb
      active-defrag-threshold-lower 10
      active-defrag-threshold-upper 100
      active-defrag-cycle-min 5
      active-defrag-cycle-max 75
      active-defrag-max-scan-fields 1000

      # Threaded I/O
      jemalloc-bg-thread yes
    '';
  };

  environment.systemPackages = with pkgs; [
    mysql84
    mycli
    postgresql
    redis
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
