{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.deskflow-client;
in {
  options.services.deskflow-client = {
    enable = mkEnableOption "Deskflow client service";

    serverAddress = mkOption {
      type = types.str;
      default = "192.168.110.160:24800";
      description = "The address of the Deskflow server to connect to";
    };

    clientName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "The name of this client";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.deskflow;
      description = "The Deskflow package to use";
    };

    debugLevel = mkOption {
      type = types.enum ["ERROR" "WARNING" "NOTE" "INFO" "DEBUG" "DEBUG1" "DEBUG2"];
      default = "INFO";
      description = "The debug level for the Deskflow client";
    };

    enableCrypto = mkOption {
      type = types.bool;
      default = true;
      description = "Enable encryption for the connection";
    };

    syncLanguage = mkOption {
      type = types.bool;
      default = true;
      description = "Synchronize language settings with the server";
    };

    tlsCertPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to the TLS certificate file. If set, bypasses certificate verification popup";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra arguments to pass to deskflow-client";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.deskflow-client = {
      description = "Deskflow client";
      wantedBy = ["graphical-session.target"];
      after = ["graphical-session.target"];

      serviceConfig = {
        ExecStart = ''
          ${cfg.package}/bin/deskflow-client -f \
            --debug ${cfg.debugLevel} \
            --name ${cfg.clientName} \
            ${optionalString cfg.enableCrypto "--enable-crypto"} \
            ${optionalString (cfg.tlsCertPath != null) "--tls-cert ${cfg.tlsCertPath}"} \
            ${optionalString cfg.syncLanguage "--sync-language"} \
            ${concatStringsSep " " cfg.extraArgs} \
            ${cfg.serverAddress}
        '';
        Restart = "always";
        RestartSec = 3;
      };
    };
  };
}
