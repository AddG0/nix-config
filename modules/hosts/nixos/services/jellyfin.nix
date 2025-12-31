{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.jellyfin;

  networkXml = pkgs.writeText "network.xml" ''
    <?xml version="1.0" encoding="utf-8"?>
    <NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <RequireHttps>${boolToString cfg.network.requireHttps}</RequireHttps>
      <BaseUrl>${cfg.network.baseUrl}</BaseUrl>
      <InternalHttpPort>${toString cfg.network.httpPort}</InternalHttpPort>
      <InternalHttpsPort>${toString cfg.network.httpsPort}</InternalHttpsPort>
      <PublicHttpPort>${toString cfg.network.publicHttpPort}</PublicHttpPort>
      <PublicHttpsPort>${toString cfg.network.publicHttpsPort}</PublicHttpsPort>
      <EnableHttps>${boolToString cfg.network.enableHttps}</EnableHttps>
      <EnableIPv4>${boolToString cfg.network.enableIPv4}</EnableIPv4>
      <EnableIPv6>${boolToString cfg.network.enableIPv6}</EnableIPv6>
      <EnableRemoteAccess>${boolToString cfg.network.enableRemoteAccess}</EnableRemoteAccess>
      <LocalNetworkSubnets>${concatStringsSep "," cfg.network.localNetworkSubnets}</LocalNetworkSubnets>
      <LocalNetworkAddresses>${concatStringsSep "," cfg.network.localNetworkAddresses}</LocalNetworkAddresses>
      <EnableUPnP>${boolToString cfg.network.enableUPnP}</EnableUPnP>
    </NetworkConfiguration>
  '';
in {
  options.services.jellyfin = {
    network = {
      enable = mkEnableOption "declarative network configuration for Jellyfin";

      httpPort = mkOption {
        type = types.port;
        default = 8096;
        description = "Internal HTTP port for Jellyfin";
      };

      httpsPort = mkOption {
        type = types.port;
        default = 8920;
        description = "Internal HTTPS port for Jellyfin";
      };

      publicHttpPort = mkOption {
        type = types.port;
        default = cfg.network.httpPort;
        defaultText = literalExpression "config.services.jellyfin.network.httpPort";
        description = "Public HTTP port for Jellyfin";
      };

      publicHttpsPort = mkOption {
        type = types.port;
        default = cfg.network.httpsPort;
        defaultText = literalExpression "config.services.jellyfin.network.httpsPort";
        description = "Public HTTPS port for Jellyfin";
      };

      requireHttps = mkOption {
        type = types.bool;
        default = false;
        description = "Require HTTPS for all connections";
      };

      enableHttps = mkOption {
        type = types.bool;
        default = false;
        description = "Enable HTTPS";
      };

      enableIPv4 = mkOption {
        type = types.bool;
        default = true;
        description = "Enable IPv4";
      };

      enableIPv6 = mkOption {
        type = types.bool;
        default = false;
        description = "Enable IPv6";
      };

      enableRemoteAccess = mkOption {
        type = types.bool;
        default = true;
        description = "Enable remote access to Jellyfin";
      };

      enableUPnP = mkOption {
        type = types.bool;
        default = false;
        description = "Enable UPnP for automatic port forwarding";
      };

      baseUrl = mkOption {
        type = types.str;
        default = "";
        description = "Base URL path for Jellyfin (e.g., /jellyfin)";
      };

      localNetworkSubnets = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of local network subnets";
      };

      localNetworkAddresses = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of local network addresses to bind to";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.network.enable) {
    systemd.services.jellyfin.preStart = mkBefore ''
      mkdir -p "${cfg.configDir}"
      ln -sf "${networkXml}" "${cfg.configDir}/network.xml"
    '';
  };
}
