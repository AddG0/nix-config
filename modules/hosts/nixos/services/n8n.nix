{ lib, config, ... }:
{
  options.services.n8n = {
    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Additional environment variables to set for the n8n service.
      '';
    };
  };

  config = lib.mkIf config.services.n8n.enable {
    systemd.services.n8n.environment = config.services.n8n.environmentVariables;
  };
}