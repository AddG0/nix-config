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

    settings = {
      mysqld = {
        innodb_buffer_pool_size = "4G";
        innodb_log_file_size = "1G";
        innodb_log_buffer_size = "64M";

        max_connections = 150;

        innodb_read_io_threads = 8;
        innodb_write_io_threads = 8;
        innodb_purge_threads = 4;

        table_open_cache = 4000;
        table_definition_cache = 2000;
        thread_cache_size = 32;

        sort_buffer_size = "4M";
        read_buffer_size = "2M";
        read_rnd_buffer_size = "8M";
        join_buffer_size = "4M";

        tmp_table_size = "256M";
        max_heap_table_size = "256M";

        performance_schema = "OFF";

        innodb_flush_method = "O_DIRECT";
        innodb_doublewrite = 0;
        innodb_flush_log_at_trx_commit = 2;
        innodb_io_capacity = 5000;
        innodb_io_capacity_max = 10000;
        innodb_file_per_table = 1;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    mysql84
    mycli
  ];
}
