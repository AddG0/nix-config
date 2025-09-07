{
  config,
  lib,
  pkgs,
  ...
}:
let

  cfg = config.services.mysql;

  isMariaDB = lib.getName cfg.package == lib.getName pkgs.mariadb;
  isOracle = lib.getName cfg.package == lib.getName pkgs.mysql80;

  mysqldOptions = "--datadir=${cfg.dataDir} --basedir=${cfg.package}";

  format = pkgs.formats.ini { listsAsDuplicateKeys = true; };
  serverConfigFile = format.generate "mysqld.cnf" cfg.settings;
  clientConfigFile = format.generate "my.cnf" {
    client.socket = "${cfg.dataDir}/mysql.sock";
    mysql.socket = "${cfg.dataDir}/mysql.sock";
  };

  generateClusterAddressExpr = ''
    if (config.services.mysql.galeraCluster.nodeAddresses == [ ]) then
      ""
    else
      "gcomm://''${builtins.concatStringsSep \",\" config.services.mysql.galeraCluster.nodeAddresses}"
      + lib.optionalString (config.services.mysql.galeraCluster.clusterPassword != "")
        "?gmcast.seg=1:''${config.services.mysql.galeraCluster.clusterPassword}"
  '';
  generateClusterAddress =
    if (cfg.galeraCluster.nodeAddresses == [ ]) then
      ""
    else
      "gcomm://${builtins.concatStringsSep "," cfg.galeraCluster.nodeAddresses}"
      + lib.optionalString (
        cfg.galeraCluster.clusterPassword != ""
      ) "?gmcast.seg=1:${cfg.galeraCluster.clusterPassword}";

  # The super user account to use on *first* run of MySQL server
  superUser = "root";

  postStartScript = pkgs.writeShellScript "mysql-post-start" ''
    # Wait until the MySQL server is available for use
    while [ ! -e "${cfg.dataDir}/mysql.sock" ]
    do
        echo "MySQL daemon not yet started. Waiting for 1 second..."
        sleep 1
    done

    # Fix socket permissions so all users can connect
    echo "Fixing MySQL socket permissions..."
    chmod 755 "${cfg.dataDir}"  # Allow access to directory
    chmod 666 "${cfg.dataDir}/mysql.sock"  # Allow socket connections

    ${lib.optionalString isMariaDB ''
      # If MariaDB is used in an Galera cluster, we have to check if the sync is done
      if ${cfg.package}/bin/mysql -u ${superUser} -S "${cfg.dataDir}/mysql.sock" -N -e "SHOW VARIABLES LIKE 'wsrep_on'" 2>/dev/null | ${lib.getExe' pkgs.gnugrep "grep"} -q 'ON'; then
        echo "Galera cluster detected, waiting for node to be synced..."
        while true; do
          STATE=$(${cfg.package}/bin/mysql -u ${superUser} -S "${cfg.dataDir}/mysql.sock" -N -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" | ${lib.getExe' pkgs.gawk "awk"} '{print $2}')
          if [ "$STATE" = "Synced" ]; then
            echo "Node is synced"
            break
          else
            echo "Current state: $STATE - Waiting for 1 second..."
            sleep 1
          fi
        done
      fi
    ''}

    # Always ensure the main user has proper socket authentication (fix any mysql_install_db defaults)
    ( echo "ALTER USER IF EXISTS '${cfg.user}'@'localhost' IDENTIFIED WITH unix_socket;"
      echo "FLUSH PRIVILEGES;"
    ) | ${cfg.package}/bin/mysql -u ${superUser} -S "${cfg.dataDir}/mysql.sock" -N 2>/dev/null || true

    if [ -f ${cfg.dataDir}/.mysql_needs_setup ]
    then
        # Create user account with proper socket authentication
        ( echo "CREATE USER IF NOT EXISTS '${cfg.user}'@'localhost' IDENTIFIED WITH unix_socket;"
          echo "GRANT ALL PRIVILEGES ON *.* TO '${cfg.user}'@'localhost' WITH GRANT OPTION;"
          echo "FLUSH PRIVILEGES;"
        ) | ${cfg.package}/bin/mysql -u ${superUser} -S "${cfg.dataDir}/mysql.sock" -N

        ${lib.concatMapStrings (database: ''
          # Create initial databases
          if ! test -e "${cfg.dataDir}/${database.name}"; then
              echo "Creating initial database: ${database.name}"
              ( echo 'CREATE DATABASE IF NOT EXISTS `${database.name}`;'

                ${lib.optionalString (database.schema != null) ''
                  echo 'USE `${database.name}`;'

                  if [ -f "${database.schema}" ]
                  then
                      cat ${database.schema}
                  elif [ -d "${database.schema}" ]
                  then
                      cat ${database.schema}/mysql-databases/*.sql
                  fi
                ''}
              ) | ${cfg.package}/bin/mysql -u ${superUser} -S "${cfg.dataDir}/mysql.sock" -N
          fi
        '') cfg.initialDatabases}

        ${lib.optionalString (cfg.replication.role == "master") ''
          # Set up the replication master
          ( echo "USE mysql;"
            echo "CREATE USER '${cfg.replication.masterUser}'@'${cfg.replication.slaveHost}' IDENTIFIED WITH mysql_native_password;"
            echo "SET PASSWORD FOR '${cfg.replication.masterUser}'@'${cfg.replication.slaveHost}' = PASSWORD('${cfg.replication.masterPassword}');"
            echo "GRANT REPLICATION SLAVE ON *.* TO '${cfg.replication.masterUser}'@'${cfg.replication.slaveHost}';"
          ) | ${cfg.package}/bin/mysql -u ${superUser} -S "${cfg.dataDir}/mysql.sock" -N
        ''}

        ${lib.optionalString (cfg.replication.role == "slave") ''
          # Set up the replication slave
          ( echo "STOP SLAVE;"
            echo "CHANGE MASTER TO MASTER_HOST='${cfg.replication.masterHost}', MASTER_USER='${cfg.replication.masterUser}', MASTER_PASSWORD='${cfg.replication.masterPassword}';"
            echo "START SLAVE;"
          ) | ${cfg.package}/bin/mysql -u ${superUser} -S "${cfg.dataDir}/mysql.sock" -N
        ''}

        ${lib.optionalString (cfg.initialScript != null) ''
          # Execute initial script
          cat ${toString cfg.initialScript} | ${cfg.package}/bin/mysql -u ${superUser} -S "${cfg.dataDir}/mysql.sock" -N
        ''}

        rm ${cfg.dataDir}/.mysql_needs_setup
    fi

    ${lib.optionalString (cfg.ensureDatabases != [ ]) ''
      (
      ${lib.concatMapStrings (database: ''
        echo "CREATE DATABASE IF NOT EXISTS \`${database}\`;"
      '') cfg.ensureDatabases}
      ) | ${cfg.package}/bin/mysql -S "${cfg.dataDir}/mysql.sock" -N
    ''}

    ${lib.concatMapStrings (user: ''
      ${if user.authentication == "socket" then ''
        ( echo "CREATE USER IF NOT EXISTS '${user.name}'@'localhost' IDENTIFIED WITH ${
          if isMariaDB then "unix_socket" else "auth_socket"
        };"
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (database: permission: ''
              echo "GRANT ${permission} ON ${database} TO '${user.name}'@'localhost';"
            '') user.ensurePermissions
          )}
          echo "FLUSH PRIVILEGES;"
        ) | ${cfg.package}/bin/mysql -S "${cfg.dataDir}/mysql.sock" -N
      '' else ''
        ( echo "CREATE USER IF NOT EXISTS '${user.name}'@'localhost' IDENTIFIED BY 'changeme';"
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (database: permission: ''
              echo "GRANT ${permission} ON ${database} TO '${user.name}'@'localhost';"
            '') user.ensurePermissions
          )}
          echo "FLUSH PRIVILEGES;"
        ) | ${cfg.package}/bin/mysql -S "${cfg.dataDir}/mysql.sock" -N
      ''}
    '') cfg.ensureUsers}
  '';
in

{
  imports = [
    (lib.mkRemovedOptionModule [
      "services"
      "mysql"
      "pidDir"
    ] "Don't wait for pidfiles, describe dependencies through launchd.")
    (lib.mkRemovedOptionModule [
      "services"
      "mysql"
      "rootPassword"
    ] "Use socket authentication or set the password outside of the nix store.")
    (lib.mkRemovedOptionModule [
      "services"
      "mysql"
      "extraOptions"
    ] "Use services.mysql.settings.mysqld instead.")
    (lib.mkRemovedOptionModule [
      "services"
      "mysql"
      "bind"
    ] "Use services.mysql.settings.mysqld.bind-address instead.")
    (lib.mkRemovedOptionModule [
      "services"
      "mysql"
      "port"
    ] "Use services.mysql.settings.mysqld.port instead.")
  ];

  ###### interface

  options = {

    services.mysql = {

      enable = lib.mkEnableOption "MySQL server";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.mariadb;
        example = lib.literalExpression "pkgs.mysql80";
        description = ''
          Which MySQL derivation to use. MariaDB packages are supported too.
        '';
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "_mysql";
        description = ''
          User account under which MySQL runs.
        '';
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "_mysql";
        description = ''
          Group account under which MySQL runs.
        '';
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/mysql";
        example = "/var/lib/mysql";
        description = ''
          The data directory for MySQL.

          ::: {.note}
          If left as the default value this directory will automatically be created before the MySQL
          server starts, otherwise you are responsible for ensuring the directory exists with appropriate ownership and permissions.
          :::
        '';
      };

      configFile = lib.mkOption {
        type = lib.types.path;
        default = serverConfigFile;
        defaultText = ''
          A configuration file automatically generated by nix-darwin.
        '';
        description = ''
          Override the configuration file used by MySQL server. By default,
          nix-darwin generates one automatically from {option}`services.mysql.settings`.
        '';
        example = lib.literalExpression ''
          pkgs.writeText "mysqld.cnf" '''
            [mysqld]
            datadir = /opt/mysql
            bind-address = 127.0.0.1
            port = 3306

            !includedir /etc/mysql/conf.d/
          ''';
        '';
      };

      settings = lib.mkOption {
        type = format.type;
        default = { };
        description = ''
          MySQL configuration. Refer to
          <https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html>,
          <https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html>,
          and <https://mariadb.com/kb/en/server-system-variables/>
          for details on supported values.

          ::: {.note}
          MySQL configuration options such as `--quick` should be treated as
          boolean options and provided values such as `true`, `false`,
          `1`, or `0`. See the provided example below.
          :::
        '';
        example = lib.literalExpression ''
          {
            mysqld = {
              key_buffer_size = "6G";
              table_cache = 1600;
              log-error = "/opt/mysql/mysql_err.log";
              plugin-load-add = [ "server_audit" "ed25519=auth_ed25519" ];
            };
            mysqldump = {
              quick = true;
              max_allowed_packet = "16M";
            };
          }
        '';
      };

      initialDatabases = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = ''
                  The name of the database to create.
                '';
              };
              schema = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = ''
                  The initial schema of the database; if null (the default),
                  an empty database is created.
                '';
              };
            };
          }
        );
        default = [ ];
        description = ''
          List of database names and their initial schemas that should be used to create databases on the first startup
          of MySQL. The schema attribute is optional: If not specified, an empty database is created.
        '';
        example = lib.literalExpression ''
          [
            { name = "foodatabase"; schema = ./foodatabase.sql; }
            { name = "bardatabase"; }
          ]
        '';
      };

      initialScript = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "A file containing SQL statements to be executed on the first startup. Can be used for granting certain permissions on the database.";
      };

      ensureDatabases = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Ensures that the specified databases exist.
          This option will never delete existing databases, especially not when the value of this
          option is changed. This means that databases created once through this option or
          otherwise have to be removed manually.
        '';
        example = [
          "nextcloud"
          "matomo"
        ];
      };

      ensureUsers = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = ''
                  Name of the user to ensure.
                '';
              };
              authentication = lib.mkOption {
                type = lib.types.enum [ "socket" "password" ];
                default = "socket";
                description = ''
                  Authentication method for the user.
                  - "socket": Uses unix_socket (MariaDB) or auth_socket (MySQL) authentication
                  - "password": Uses mysql_native_password authentication (requires password to be set separately)
                '';
              };
              ensurePermissions = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
                description = ''
                  Permissions to ensure for the user, specified as attribute set.
                  The attribute names specify the database and tables to grant the permissions for,
                  separated by a dot. You may use wildcards here.
                  The attribute values specfiy the permissions to grant.
                  You may specify one or multiple comma-separated SQL privileges here.

                  For more information on how to specify the target
                  and on which privileges exist, see the
                  [GRANT syntax](https://mariadb.com/kb/en/library/grant/).
                  The attributes are used as `GRANT ''${attrName} ON ''${attrValue}`.
                '';
                example = lib.literalExpression ''
                  {
                    "database.*" = "ALL PRIVILEGES";
                    "*.*" = "SELECT, LOCK TABLES";
                  }
                '';
              };
            };
          }
        );
        default = [ ];
        description = ''
          Ensures that the specified users exist and have at least the ensured permissions.
          By default, users are created with socket authentication, but this can be changed
          using the authentication option.
          This option will never delete existing users or remove permissions, especially not when the value of this
          option is changed. This means that users created and permissions assigned once through this option or
          otherwise have to be removed manually.
        '';
        example = lib.literalExpression ''
          [
            {
              name = "nextcloud";
              authentication = "socket";
              ensurePermissions = {
                "nextcloud.*" = "ALL PRIVILEGES";
              };
            }
            {
              name = "admin";
              authentication = "password";
              ensurePermissions = {
                "*.*" = "ALL PRIVILEGES";
              };
            }
          ]
        '';
      };

      replication = {
        role = lib.mkOption {
          type = lib.types.enum [
            "master"
            "slave"
            "none"
          ];
          default = "none";
          description = "Role of the MySQL server instance.";
        };

        serverId = lib.mkOption {
          type = lib.types.int;
          default = 1;
          description = "Id of the MySQL server instance. This number must be unique for each instance.";
        };

        masterHost = lib.mkOption {
          type = lib.types.str;
          description = "Hostname of the MySQL master server.";
        };

        slaveHost = lib.mkOption {
          type = lib.types.str;
          description = "Hostname of the MySQL slave server.";
        };

        masterUser = lib.mkOption {
          type = lib.types.str;
          description = "Username of the MySQL replication user.";
        };

        masterPassword = lib.mkOption {
          type = lib.types.str;
          description = "Password of the MySQL replication user.";
        };

        masterPort = lib.mkOption {
          type = lib.types.port;
          default = 3306;
          description = "Port number on which the MySQL master server runs.";
        };
      };

      galeraCluster = {
        enable = lib.mkEnableOption "MariaDB Galera Cluster";

        package = lib.mkOption {
          type = lib.types.package;
          description = "The MariaDB Galera package that provides the shared library 'libgalera_smm.so' required for cluster functionality.";
          default = lib.literalExpression "pkgs.mariadb-galera";
        };

        name = lib.mkOption {
          type = lib.types.str;
          description = "The logical name of the Galera cluster. All nodes in the same cluster must use the same name.";
          default = "galera";
        };

        sstMethod = lib.mkOption {
          type = lib.types.enum [
            "rsync"
            "mariabackup"
          ];
          description = "Method for the initial state transfer (wsrep_sst_method) when a node joins the cluster. Be aware that rsync needs SSH keys to be generated and authorized on all nodes!";
          default = "rsync";
          example = "mariabackup";
        };

        localName = lib.mkOption {
          type = lib.types.str;
          description = "The unique name that identifies this particular node within the cluster. Each node must have a different name.";
          example = "node1";
        };

        localAddress = lib.mkOption {
          type = lib.types.str;
          description = "IP address or hostname of this node that will be used for cluster communication. Must be reachable by all other nodes.";
          example = "1.2.3.4";
          default = cfg.galeraCluster.localName;
          defaultText = lib.literalExpression "config.services.mysql.galeraCluster.localName";
        };

        nodeAddresses = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "IP addresses or hostnames of all nodes in the cluster, including this node. This is used to construct the default clusterAddress connection string.";
          example = lib.literalExpression ''["10.0.0.10" "10.0.0.20" "10.0.0.30"]'';
          default = [ ];
        };

        clusterPassword = lib.mkOption {
          type = lib.types.str;
          description = "Optional password for securing cluster communications. If provided, it will be used in the clusterAddress for authentication between nodes.";
          example = "SomePassword";
          default = "";
        };

        clusterAddress = lib.mkOption {
          type = lib.types.str;
          description = "Full Galera cluster connection string. If nodeAddresses is set, this will be auto-generated, but you can override it with a custom value. Format is typically 'gcomm://node1,node2,node3' with optional parameters.";
          example = "gcomm://10.0.0.10,10.0.0.20,10.0.0.30?gmcast.seg=1:SomePassword";
          default = ""; # will be evaluate by generateClusterAddress
          defaultText = lib.literalExpression generateClusterAddressExpr;
        };

      };
    };

  };

  ###### implementation

  config = lib.mkIf cfg.enable {
    assertions =
      [
        {
          assertion = !cfg.galeraCluster.enable || isMariaDB;
          message = "'services.mysql.galeraCluster.enable' expect services.mysql.package to be an mariadb variant";
        }
        {
          assertion = lib.hasPrefix "/opt" cfg.dataDir || lib.hasPrefix "/usr/local" cfg.dataDir || lib.hasPrefix "/var" cfg.dataDir;
          message = "MySQL data directory should be in a system location like /opt, /usr/local, or /var. Current path: ${cfg.dataDir}";
        }
        {
          assertion = cfg.settings.mysqld.port or 3306 >= 1024;
          message = "MySQL port must be >= 1024 for non-root users. Current port: ${toString (cfg.settings.mysqld.port or 3306)}";
        }
        {
          assertion = cfg.replication.role == "none" || (cfg.replication.role != "none" && cfg.replication.serverId > 0);
          message = "When MySQL replication is enabled, serverId must be greater than 0";
        }
        {
          assertion = cfg.replication.role != "slave" || (cfg.replication.masterHost != "" && cfg.replication.masterUser != "");
          message = "When MySQL replication role is 'slave', masterHost and masterUser must be specified";
        }
        {
          assertion = cfg.replication.role != "master" || cfg.replication.slaveHost != "";
          message = "When MySQL replication role is 'master', slaveHost must be specified";
        }
        {
          assertion = !cfg.galeraCluster.enable || (cfg.settings.mysqld.bind-address or "127.0.0.1") != "127.0.0.1";
          message = "Galera cluster requires bind-address to be set to a network interface (not 127.0.0.1) for cluster communication";
        }
      ]
      # galeraCluster options checks
      ++ lib.optionals cfg.galeraCluster.enable [
        {
          assertion =
            cfg.galeraCluster.localAddress != ""
            && (cfg.galeraCluster.nodeAddresses != [ ] || cfg.galeraCluster.clusterAddress != "");
          message = "mariadb galera cluster is enabled but the localAddress and (nodeAddresses or clusterAddress) are not set";
        }
        {
          assertion = cfg.galeraCluster.clusterPassword == "" || cfg.galeraCluster.clusterAddress == "";
          message = "mariadb galera clusterPassword is set but overwritten by clusterAddress";
        }
        {
          assertion = cfg.galeraCluster.nodeAddresses != [ ] || cfg.galeraCluster.clusterAddress != "";
          message = "When services.mysql.galeraCluster.clusterAddress is set, setting services.mysql.galeraCluster.nodeAddresses is redundant and will be overwritten by clusterAddress. Choose one approach.";
        }
        {
          assertion = cfg.galeraCluster.localName != "";
          message = "Galera cluster requires a unique localName for this node";
        }
      ];

    services.mysql.settings = lib.mkMerge [
      {
        client = {
          socket = lib.mkDefault "${cfg.dataDir}/mysql.sock";
        };
        mysql = {
          socket = lib.mkDefault "${cfg.dataDir}/mysql.sock";
        };
        mysqld = {
          datadir = cfg.dataDir;
          port = lib.mkDefault 3306;
          socket = lib.mkDefault "${cfg.dataDir}/mysql.sock";
          pid-file = lib.mkDefault "${cfg.dataDir}/mysql.pid";
          bind-address = lib.mkDefault "127.0.0.1";
          # Ensure MariaDB doesn't try to create system directories
          skip-name-resolve = lib.mkDefault true;
          tmpdir = lib.mkDefault cfg.dataDir;
        };
      }
      (lib.mkIf (cfg.replication.role == "master" || cfg.replication.role == "slave") {
        mysqld = {
          log-bin = "mysql-bin-${toString cfg.replication.serverId}";
          log-bin-index = "mysql-bin-${toString cfg.replication.serverId}.index";
          relay-log = "mysql-relay-bin";
          server-id = cfg.replication.serverId;
          binlog-ignore-db = [
            "information_schema"
            "performance_schema"
            "mysql"
          ];
        };
      })
      (lib.mkIf (!isMariaDB) {
        mysqld = {
          plugin-load-add = [ "auth_socket.so" ];
        };
      })
      (lib.mkIf cfg.galeraCluster.enable {
        mysqld = {
          # Ensure Only InnoDB is used as galera clusters can only work with them
          enforce_storage_engine = "InnoDB";
          default_storage_engine = "InnoDB";

          # galera only support this binlog format
          binlog-format = "ROW";

          bind_address = lib.mkDefault "0.0.0.0";
        };
        galera = {
          wsrep_on = "ON";
          wsrep_debug = lib.mkDefault "NONE";
          wsrep_retry_autocommit = lib.mkDefault "3";
          wsrep_provider = "${cfg.galeraCluster.package}/lib/galera/libgalera_smm.so";

          wsrep_cluster_name = cfg.galeraCluster.name;
          wsrep_cluster_address =
            if (cfg.galeraCluster.clusterAddress != "") then
              cfg.galeraCluster.clusterAddress
            else
              generateClusterAddress;

          wsrep_node_address = cfg.galeraCluster.localAddress;
          wsrep_node_name = "${cfg.galeraCluster.localName}";

          # SST method using rsync
          wsrep_sst_method = lib.mkDefault cfg.galeraCluster.sstMethod;
          wsrep_sst_auth = lib.mkDefault "check_repl:check_pass";

          binlog_format = "ROW";
          innodb_autoinc_lock_mode = 2;
        };
      })
    ];

    users.users._mysql = {
      uid = config.ids.uids._mysql;
      gid = config.ids.gids._mysql;
      shell = "/usr/bin/false";
      description = "System user for MySQL";
    };

    users.groups._mysql = {
      gid = config.ids.gids._mysql;
      description = "System group for MySQL";
    };

    users.knownGroups = [ "_mysql" ];
    users.knownUsers = [ "_mysql" ];

    environment.systemPackages = [
      cfg.package
      # Add MySQL service management scripts
      (pkgs.writeShellScriptBin "mysql-start" ''
        echo "Starting MySQL service..."
        sudo launchctl load /Library/LaunchDaemons/org.nixos.mysql.plist 2>/dev/null || echo "Service already loaded"
        echo "MySQL service started"
      '')
      (pkgs.writeShellScriptBin "mysql-stop" ''
        echo "Stopping MySQL service..."
        sudo launchctl unload /Library/LaunchDaemons/org.nixos.mysql.plist 2>/dev/null || echo "Service not loaded"
        echo "MySQL service stopped"
      '')
      (pkgs.writeShellScriptBin "mysql-restart" ''
        echo "Restarting MySQL service..."
        sudo launchctl unload /Library/LaunchDaemons/org.nixos.mysql.plist 2>/dev/null || echo "Service not loaded"
        sleep 2
        sudo launchctl load /Library/LaunchDaemons/org.nixos.mysql.plist
        echo "MySQL service restarted"
      '')
      (pkgs.writeShellScriptBin "mysql-status" ''
        if sudo launchctl list | grep -q "org.nixos.mysql"; then
          PID=$(sudo launchctl list | grep "org.nixos.mysql" | awk '{print $1}')
          if [[ "$PID" =~ ^[0-9]+$ ]]; then
            echo "MySQL service is running (PID: $PID)"
            if [[ -e "${cfg.dataDir}/mysql.sock" ]]; then
              echo "Socket: ${cfg.dataDir}/mysql.sock (accessible)"
            else
              echo "Socket: ${cfg.dataDir}/mysql.sock (not found)"
            fi
          else
            echo "MySQL service is loaded but not running (status: $PID)"
          fi
        else
          echo "MySQL service is not loaded"
        fi
      '')
      (pkgs.writeShellScriptBin "mysql-logs" ''
        echo "=== MySQL Error Log ==="
        if [[ -f "${cfg.dataDir}/mysql.error.log" ]]; then
          tail -n 20 "${cfg.dataDir}/mysql.error.log"
        else
          echo "Error log not found"
        fi
        echo
        echo "=== MySQL General Log ==="
        if [[ -f "${cfg.dataDir}/mysql.log" ]]; then
          tail -n 20 "${cfg.dataDir}/mysql.log"
        else
          echo "General log not found"
        fi
      '')
    ];

    environment.etc."my.cnf".source = clientConfigFile;

    # Create MySQL data directory
    system.activationScripts.extraActivation.text = lib.mkAfter ''
      if [[ ! -d "${cfg.dataDir}" ]]; then
        echo "Creating MySQL data directory..."
        mkdir -p "${cfg.dataDir}"
        chown ${cfg.user}:${cfg.group} "${cfg.dataDir}"
        chmod 700 "${cfg.dataDir}"
      fi
    '';

    launchd.daemons.mysql =
      let
        initAndStartScript = pkgs.writeShellScript "mysql-init-and-start" ''
          set -euo pipefail

          log() {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
          }

          cleanup() {
            if [[ -n "''${MYSQL_PID:-}" ]] && kill -0 "$MYSQL_PID" 2>/dev/null; then
              log "Shutting down MySQL (PID: $MYSQL_PID)"
              kill "$MYSQL_PID"
              wait "$MYSQL_PID" 2>/dev/null || true
            fi
          }
          trap cleanup EXIT INT TERM

          # Verify data directory exists (should be created by user home)
          if [[ ! -d "${cfg.dataDir}" ]]; then
            log "ERROR: MySQL data directory ${cfg.dataDir} does not exist!"
            log "This should have been created by the system user home."
            exit 1
          fi

          # Initialize database if needed
          INIT_MARKER="${cfg.dataDir}/.mysql_initialized"

          if [[ ! -d "${cfg.dataDir}/mysql" ]] || [[ ! -f "$INIT_MARKER" ]]; then
            log "Initializing MySQL database..."

            # Clean up any partial initialization
            if [[ -d "${cfg.dataDir}/mysql" ]] && [[ ! -f "$INIT_MARKER" ]]; then
              log "Cleaning up partial initialization..."
              rm -rf "${cfg.dataDir}/mysql" "${cfg.dataDir}"/*.log "${cfg.dataDir}"/*.pid 2>/dev/null || true
            fi

            log "Running mysql_install_db with detailed output..."
            ${if isMariaDB then ''
              log "Command: ${cfg.package}/bin/mysql_install_db --defaults-file=${cfg.configFile} ${mysqldOptions} --user=${cfg.user}"
              if ! ${cfg.package}/bin/mysql_install_db --defaults-file=${cfg.configFile} ${mysqldOptions} --user=${cfg.user}; then
                log "ERROR: mysql_install_db failed with exit code $?"
                log "Check the output above for specific error details"
                exit 1
              fi
            '' else ''
              log "Command: ${cfg.package}/bin/mysqld --defaults-file=${cfg.configFile} ${mysqldOptions} --initialize-insecure --user=${cfg.user}"
              if ! ${cfg.package}/bin/mysqld --defaults-file=${cfg.configFile} ${mysqldOptions} --initialize-insecure --user=${cfg.user}; then
                log "ERROR: mysqld --initialize-insecure failed with exit code $?"
                log "Check the output above for specific error details"
                exit 1
              fi
            ''}

            # Verify the initialization worked
            if [[ ! -d "${cfg.dataDir}/mysql" ]]; then
              log "ERROR: mysql directory was not created after initialization"
              exit 1
            fi

            # Mark as needing post-initialization setup
            log "Creating setup marker for post-initialization configuration"
            touch "${cfg.dataDir}/.mysql_needs_setup"

            # Mark as initialized
            echo "$(date): Database initialized successfully" > "$INIT_MARKER"
            log "Database initialization completed successfully"
          fi

          # Start MySQL daemon in background
          log "Starting MySQL daemon..."
          ${cfg.package}/bin/mysqld --defaults-file=${cfg.configFile} ${mysqldOptions} &
          MYSQL_PID=$!
          log "MySQL daemon started with PID: $MYSQL_PID"

          # Wait for MySQL to be ready with timeout
          log "Waiting for MySQL to be ready..."
          TIMEOUT=30
          COUNTER=0
          while [ ! -e "${cfg.dataDir}/mysql.sock" ]; do
            if ! kill -0 $MYSQL_PID 2>/dev/null; then
              log "ERROR: MySQL daemon (PID: $MYSQL_PID) exited unexpectedly"
              log "Check ${cfg.dataDir}/mysql.error.log for details"
              exit 1
            fi
            if [ $COUNTER -ge $TIMEOUT ]; then
              log "ERROR: MySQL failed to start within $TIMEOUT seconds"
              log "Check ${cfg.dataDir}/mysql.error.log for details"
              exit 1
            fi
            sleep 1
            COUNTER=$((COUNTER + 1))
          done
          log "MySQL is ready (socket: ${cfg.dataDir}/mysql.sock)"

          # Run post-start configuration
          log "Running post-start configuration..."
          if ! ${postStartScript}; then
            log "ERROR: Post-start configuration failed"
            exit 1
          fi
          log "Post-start configuration completed"

          # Wait for MySQL daemon to finish
          log "MySQL service is running. Waiting for shutdown signal..."
          wait $MYSQL_PID
        '';
      in
      {
        script = "${initAndStartScript}";
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          ProcessType = "Background";
          StandardOutPath = "${cfg.dataDir}/mysql.log";
          StandardErrorPath = "${cfg.dataDir}/mysql.error.log";
          UserName = cfg.user;
          GroupName = cfg.group;
          WorkingDirectory = cfg.dataDir;
        };
      };
  };

  meta.maintainers = [ lib.maintainers._6543 ];
}