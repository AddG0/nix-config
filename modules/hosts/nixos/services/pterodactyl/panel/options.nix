{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.services.pterodactyl.panel;
in {
  options.services.pterodactyl.panel = {
    enable = mkEnableOption "Enable Pterodactyl Panel";

    package = mkOption {
      type = types.package;
      default = let
        bpExtensions = lib.optionals cfg.blueprint.enable (lib.attrValues cfg.blueprint.extensions);
        withBlueprint =
          if bpExtensions == []
          then pkgs.pterodactyl-panel
          else
            import ./bake-blueprint.nix {inherit pkgs lib;} {
              panel = pkgs.pterodactyl-panel;
              inherit (pkgs) blueprint;
              extensions = bpExtensions;
            };
      in
        if cfg.addons == []
        then withBlueprint
        else
          import ./bake-addons.nix {inherit pkgs lib;} {
            panel = withBlueprint;
            inherit (cfg) addons;
          };
      defaultText = literalExpression "pkgs.pterodactyl-panel (with Blueprint extensions + addons baked in)";
      description = "The built Pterodactyl panel package served read-only from the store.";
    };

    addons = mkOption {
      default = [];
      description = ''
        Non-Blueprint addons (themes, etc.) baked into the panel package at
        build time. Each supplies its own build-time `install` snippet, since
        addons ship their own install procedures.
      '';
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Identifier for logging.";
          };
          source = mkOption {
            type = types.either types.str types.path;
            description = "The addon archive/file (build input).";
          };
          install = mkOption {
            type = types.lines;
            description = ''
              Bash run at build time with the panel tree as CWD and the source
              at $src (addons ship their own install procedures).
            '';
          };
          needsAssetBuild = mkOption {
            type = types.bool;
            default = false;
            description = "Run a webpack rebuild after this addon (front-end source changes).";
          };
        };
      });
    };

    phpPackage = mkOption {
      type = types.package;
      default = pkgs.php83;
      defaultText = literalExpression "pkgs.php83";
      description = ''
        Base PHP package used for php-fpm and artisan. Matches the PHP the
        panel package's composer deps were resolved against.
      '';
    };

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

    hostName = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "panel.example.com";
      description = "FQDN for the panel's nginx vhost. Null → no vhost is defined.";
    };

    acmeHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "ACME certificate host for the vhost (nginx useACMEHost).";
    };

    stateDir = mkOption {
      type = types.path;
      # NB: not /var/lib/pterodactyl — that is Wings' root_directory (game-server
      # volumes). The panel keeps its state separate.
      default = "/var/lib/pterodactyl-panel";
      description = ''
        Writable state directory: holds the generated .env, storage/, and the
        compiled-cache dir. The panel code itself is served read-only from the
        Nix store, never from here.
      '';
    };

    appKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a file containing the Laravel APP_KEY (e.g. a sops secret).
        If null, one is generated and persisted in stateDir on first run.
        Changing/losing it invalidates all encrypted values (node daemon tokens).
      '';
    };

    ssl = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable SSL/ACME.";
    };

    url = mkOption {
      type = types.str;
      default = "http://localhost";
      example = "https://panel.example.com";
      description = "Public base URL of the panel (APP_URL).";
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
