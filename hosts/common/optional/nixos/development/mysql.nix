{pkgs, ...}: {
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

  environment.systemPackages = with pkgs; [
    mysql84
    mycli
  ];
}
