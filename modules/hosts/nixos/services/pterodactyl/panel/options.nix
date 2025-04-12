{lib, ...}:
with lib; {
  options.services.pterodactyl.panel = {
    enable = mkEnableOption "Enable Pterodactyl Panel";

    user = mkOption {
      type = types.str;
      default = "pterodactyl";
      description = "User under which the panel will run.";
    };

    group = mkOption {
      type = types.str;
      default = "pterodactyl";
      description = "Group under which the panel will run.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/www/pterodactyl";
      description = "Directory where the panel files are stored.";
    };

    ssl = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable SSL/ACME.";
    };

    database = {
      name = mkOption {
        type = types.str;
        default = "panel";
      };
      user = mkOption {
        type = types.str;
        default = "pterodactyl";
      };
      host = mkOption {
        type = types.str;
        default = "localhost";
      };
    };

    users = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          email = mkOption {
            type = types.str;
            description = "Email address for this user.";
          };
          username = mkOption {
            type = types.str;
            description = "Username for this user.";
          };
          firstName = mkOption {
            type = types.str;
            description = "First name of the user.";
          };
          lastName = mkOption {
            type = types.str;
            description = "Last name of the user.";
          };
          passwordFile = mkOption {
            type = types.path;
            description = "Path to file containing this user's password.";
          };
          isAdmin = mkOption {
            type = types.bool;
            default = false;
            description = "Whether this user should be an admin.";
          };
        };
      });
      default = {};
      description = "Map of panel users to create.";
    };

    nodes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "The name of the node.";
          };

          description = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Optional description for the node.";
          };

          location = lib.mkOption {
            type = lib.types.str;
            description = "The `short` identifier of the location this node belongs to.";
          };

          fqdn = lib.mkOption {
            type = lib.types.str;
            description = "The fully-qualified domain name (FQDN) of the node.";
          };

          scheme = lib.mkOption {
            type = lib.types.enum ["http" "https"];
            default = "https";
            description = "The scheme used to connect to the node.";
          };

          behindProxy = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether the node is behind a proxy.";
          };

          maintenanceMode = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether the node is in maintenance mode.";
          };

          memory = lib.mkOption {
            type = lib.types.ints.positive;
            description = "Memory in MB allocated to the node.";
          };

          memoryOverallocate = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = "Memory overallocation in percent (can be negative).";
          };

          disk = lib.mkOption {
            type = lib.types.ints.positive;
            description = "Disk in MB allocated to the node.";
          };

          diskOverallocate = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = "Disk overallocation in percent (can be negative).";
          };

          uploadSize = lib.mkOption {
            type = lib.types.ints.positive;
            default = 100;
            description = "Upload size limit in MB.";
          };

          daemonListen = lib.mkOption {
            type = lib.types.port;
            default = 8080;
            description = "Port the daemon listens on.";
          };

          daemonSFTP = lib.mkOption {
            type = lib.types.port;
            default = 2022;
            description = "Port the daemon uses for SFTP.";
          };

          daemonBase = lib.mkOption {
            type = lib.types.path;
            default = "/home/daemon-files";
            description = "Base directory for daemon files.";
          };

          daemonTokenId = lib.mkOption {
            type = lib.types.str;
            description = "Daemon token ID for the node.";
          };

          daemonToken = lib.mkOption {
            type = lib.types.str;
            description = "Daemon token (secret) for the node.";
          };

          allocations = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                ip = lib.mkOption {
                  type = lib.types.str;
                  description = "IP address used for this allocation.";
                };

                ipAlias = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Optional alias for the IP address.";
                };

                port = lib.mkOption {
                  type = lib.types.port;
                  description = "Port used for this allocation.";
                };

                notes = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Optional note for this allocation.";
                };
              };
            });

            default = [];
            description = "List of IP and port allocations for the node.";
          };
        };
      });

      default = {};
      description = "Map of nodes to be added to the Pterodactyl Panel.";
    };
    locations = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          short = lib.mkOption {
            type = lib.types.str;
            description = "Short identifier for the location (e.g. 'us-east'). Must be unique.";
          };

          long = lib.mkOption {
            type = lib.types.str;
            description = "Long description for the location.";
          };
        };
      });

      default = {};
      description = "Map of locations to be added to the Pterodactyl Panel.";
    };
  };
}
