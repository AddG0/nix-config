{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    escapeShellArgs
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.loki;

  prettyJSON =
    conf:
    pkgs.runCommand "loki-config.json" { } ''
      echo '${builtins.toJSON conf}' | ${pkgs.jq}/bin/jq 'del(._module)' > $out
    '';

in
{
  options.services.loki = {
    enable = mkEnableOption "loki";

    user = mkOption {
      type = types.str;
      default = "_loki";
      description = ''
        User under which the Loki service runs.
      '';
    };

    package = lib.mkPackageOption pkgs "grafana-loki" { };

    group = mkOption {
      type = types.str;
      default = "_loki";
      description = ''
        Group under which the Loki service runs.
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/loki";
      description = ''
        Specify the directory for Loki.

        ::: {.note}
        If left as the default value this directory will automatically be created before Loki
        starts, otherwise you are responsible for ensuring the directory exists with appropriate ownership and permissions.
        :::
      '';
    };

    configuration = mkOption {
      type = (pkgs.formats.json { }).type;
      default = { };
      description = ''
        Specify the configuration for Loki in Nix.
      '';
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Specify a configuration file that Loki should use.
      '';
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--server.http-listen-port=3101" ];
      description = ''
        Specify a list of additional command line flags,
        which get escaped and are then passed to Loki.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (
          (cfg.configuration == { } -> cfg.configFile != null)
          && (cfg.configFile != null -> cfg.configuration == { })
        );
        message = ''
          Please specify either
          'services.loki.configuration' or
          'services.loki.configFile'.
        '';
      }
      {
        assertion = lib.hasPrefix "/opt" cfg.dataDir || lib.hasPrefix "/usr/local" cfg.dataDir || lib.hasPrefix "/var" cfg.dataDir;
        message = "Loki data directory should be in a system location like /opt, /usr/local, or /var. Current path: ${cfg.dataDir}";
      }
    ];

    users.users._loki = {
      uid = config.ids.uids._loki;
      gid = config.ids.gids._loki;
      shell = "/usr/bin/false";
      description = "System user for Loki";
    };

    users.groups._loki = {
      gid = config.ids.gids._loki;
      description = "System group for Loki";
    };

    users.knownGroups = [ "_loki" ];
    users.knownUsers = [ "_loki" ];

    environment.systemPackages = [ 
      cfg.package # logcli
      # Add Loki service management scripts
      (pkgs.writeShellScriptBin "loki-start" ''
        echo "Starting Loki service..."
        sudo launchctl load /Library/LaunchDaemons/org.nixos.loki.plist 2>/dev/null || echo "Service already loaded"
        echo "Loki service started"
      '')
      (pkgs.writeShellScriptBin "loki-stop" ''
        echo "Stopping Loki service..."
        sudo launchctl unload /Library/LaunchDaemons/org.nixos.loki.plist 2>/dev/null || echo "Service not loaded"
        echo "Loki service stopped"
      '')
      (pkgs.writeShellScriptBin "loki-restart" ''
        echo "Restarting Loki service..."
        sudo launchctl unload /Library/LaunchDaemons/org.nixos.loki.plist 2>/dev/null || echo "Service not loaded"
        sleep 2
        sudo launchctl load /Library/LaunchDaemons/org.nixos.loki.plist
        echo "Loki service restarted"
      '')
      (pkgs.writeShellScriptBin "loki-status" ''
        if sudo launchctl list | grep -q "org.nixos.loki"; then
          PID=$(sudo launchctl list | grep "org.nixos.loki" | awk '{print $1}')
          if [[ "$PID" =~ ^[0-9]+$ ]]; then
            echo "Loki service is running (PID: $PID)"
            # Loki typically runs on port 3100 by default
            echo "HTTP API: http://127.0.0.1:3100"
            echo "Ready endpoint: http://127.0.0.1:3100/ready"
          else
            echo "Loki service is loaded but not running (status: $PID)"
          fi
        else
          echo "Loki service is not loaded"
        fi
      '')
      (pkgs.writeShellScriptBin "loki-logs" ''
        echo "=== Loki Service Logs ==="
        if [[ -f "${cfg.dataDir}/loki.log" ]]; then
          tail -n 50 "${cfg.dataDir}/loki.log"
        else
          echo "Log file not found at ${cfg.dataDir}/loki.log"
        fi
      '')
    ];

    # Create Loki directory
    system.activationScripts.extraActivation.text = lib.mkAfter ''
      echo "creating Loki directory..."
      mkdir -p ${cfg.dataDir}
      chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
      chmod -R 755 ${cfg.dataDir}
    '';

    launchd.daemons.loki =
      let
        conf =
          if cfg.configFile == null then
            # Config validation may fail when using extraFlags = [ "-config.expand-env=true" ].
            # To work around this, we simply skip it when extraFlags is not empty.
            if cfg.extraFlags == [ ] then
              validateConfig (prettyJSON cfg.configuration)
            else
              prettyJSON cfg.configuration
          else
            cfg.configFile;
        validateConfig =
          file:
          pkgs.runCommand "validate-loki-conf"
            {
              nativeBuildInputs = [ cfg.package ];
            }
            ''
              loki -verify-config -config.file "${file}"
              ln -s "${file}" "$out"
            '';
        lokiScript = pkgs.writeShellScript "loki-daemon" ''
          set -euo pipefail

          log() {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
          }

          cleanup() {
            if [[ -n "''${LOKI_PID:-}" ]] && kill -0 "$LOKI_PID" 2>/dev/null; then
              log "Shutting down Loki (PID: $LOKI_PID)"
              kill "$LOKI_PID"
              wait "$LOKI_PID" 2>/dev/null || true
            fi
          }
          trap cleanup EXIT INT TERM

          # Verify data directory exists
          if [[ ! -d "${cfg.dataDir}" ]]; then
            log "ERROR: Loki data directory ${cfg.dataDir} does not exist!"
            exit 1
          fi

          # Start Loki in background
          log "Starting Loki daemon..."
          log "Command: ${cfg.package}/bin/loki --config.file=${conf} ${escapeShellArgs cfg.extraFlags}"
          ${cfg.package}/bin/loki --config.file=${conf} ${escapeShellArgs cfg.extraFlags} &
          LOKI_PID=$!
          log "Loki daemon started with PID: $LOKI_PID"

          # Wait for Loki to be ready
          log "Waiting for Loki to be ready..."
          TIMEOUT=30
          COUNTER=0
          # Loki exposes a /ready endpoint when it's ready to receive traffic
          while ! curl -s "http://127.0.0.1:3100/ready" > /dev/null 2>&1; do
            if ! kill -0 $LOKI_PID 2>/dev/null; then
              log "ERROR: Loki daemon (PID: $LOKI_PID) exited unexpectedly"
              exit 1
            fi
            if [ $COUNTER -ge $TIMEOUT ]; then
              log "ERROR: Loki failed to start within $TIMEOUT seconds"
              exit 1
            fi
            sleep 1
            COUNTER=$((COUNTER + 1))
          done
          log "Loki is ready at http://127.0.0.1:3100"

          # Wait for Loki daemon to finish
          log "Loki service is running. Waiting for shutdown signal..."
          wait $LOKI_PID
        '';
      in
      {
        script = "${lokiScript}";
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          ProcessType = "Background";
          StandardOutPath = "${cfg.dataDir}/loki.log";
          StandardErrorPath = "${cfg.dataDir}/loki.error.log";
          UserName = cfg.user;
          GroupName = cfg.group;
          WorkingDirectory = cfg.dataDir;
          EnvironmentVariables = {
            HOME = cfg.dataDir;
          };
        };
      };
  };
}