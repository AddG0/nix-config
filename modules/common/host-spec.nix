# Specifications For Differentiating Hosts
{
  config,
  pkgs,
  lib,
  ...
}: {
  options.hostSpec = {
    # ============================================================================
    # User Information
    # ============================================================================
    username = lib.mkOption {
      type = lib.types.str;
      description = "The username of the host";
    };

    userFullName = lib.mkOption {
      type = lib.types.str;
      description = "The full name of the user";
    };

    handle = lib.mkOption {
      type = lib.types.str;
      description = "The handle of the user (eg: github user)";
    };

    email = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "The email of the user";
    };

    githubEmail = lib.mkOption {
      type = lib.types.str;
      description = "The github email of the user";
    };

    # ============================================================================
    # Host Information
    # ============================================================================
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "The hostname of the host";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "The domain of the host";
    };

    hostPlatform = lib.mkOption {
      type = lib.types.str;
      description = "The platform of the host";
    };

    home = lib.mkOption {
      type = lib.types.str;
      description = "The home directory of the user";
      default = let
        user = config.hostSpec.username;
      in
        if pkgs.stdenv.isLinux
        then "/home/${user}"
        else "/Users/${user}";
    };

    # FIXME: This should probably just switch to an impermenance option?
    persistFolder = lib.mkOption {
      type = lib.types.str;
      description = "The folder to persist data if impermenance is enabled";
      default = "/persist";
    };

    # ============================================================================
    # Host Type and Characteristics
    # ============================================================================
    hostType = lib.mkOption {
      type = lib.types.enum ["server" "desktop" "laptop"];
      default = "desktop";
      description = "The type of host (server, desktop, or laptop)";
    };

    isMinimal = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Used to indicate a minimal host";
    };

    isProduction = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Used to indicate a production host";
    };

    isWork = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Used to indicate a host that uses work resources";
    };

    # ============================================================================
    # Work Configuration
    # ============================================================================
    # FIXME: Set an assert to make sure this is set if isWork is true
    work = lib.mkOption {
      default = {};
      type = lib.types.attrsOf lib.types.anything;
      description = "An attribute set of work-related information if isWork is true";
    };

    # ============================================================================
    # Networking Configuration
    # ============================================================================
    networking = lib.mkOption {
      default = {};
      type = lib.types.attrsOf lib.types.anything;
      description = "An attribute set of networking information";
    };

    # ============================================================================
    # Deployment Configuration
    # ============================================================================
    colmena = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable deployment via Colmena";
      };

      targetHost = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "The target hostname or IP address for Colmena deployment";
      };
    };

    # ============================================================================
    # Platform-specific Configuration
    # ============================================================================
    # Sometimes we can't use pkgs.stdenv.isLinux due to infinite recursion
    isDarwin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Used to indicate a host that is darwin";
    };

    darwin = {
      isAarch64 = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Used to indicate a host that is darwin aarch64";
      };

      hasPaidApps = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Used to indicate a host that has paid apps";
      };
    };

    # ============================================================================
    # Security and Secrets
    # ============================================================================
    disableSops = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Used to disable sops for the host";
    };

    # ============================================================================
    # System Configuration
    # ============================================================================
    system.stateVersion = lib.mkOption {
      type = lib.types.str;
      description = "The state version of the host";
    };

    # ============================================================================
    # Telemetry Configuration
    # ============================================================================
    telemetry = {
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Global toggle to enable telemetry across the system";
      };

      claude-code.enabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable OTLP telemetry for Claude Code";
      };
    };
  };

  config = {
    assertions = let
      # We import these options to HM and NixOS, so need to not fail on HM
      isImpermanent =
        config ? "system" && config.system ? "impermanence" && config.system.impermanence.enable;
    in [
      {
        assertion = !builtins.isNull config.hostSpec.hostPlatform;
        message = "hostPlatform must be set";
      }
      {
        assertion =
          !config.hostSpec.isWork || (config.hostSpec.isWork && !builtins.isNull config.hostSpec.work);
        message = "isWork is true but no work attribute set is provided";
      }
      {
        assertion = !isImpermanent || (isImpermanent && "${config.hostSpec.persistFolder}" != "");
        message = "config.system.impermanence.enable is true but no persistFolder path is provided";
      }
    ];
  };
}
