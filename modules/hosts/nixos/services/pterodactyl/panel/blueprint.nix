{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.pterodactyl.panel.blueprint;
  pterodactylCfg = config.services.pterodactyl.panel;
in {
  options.services.pterodactyl.panel.blueprint = {
    enable = mkEnableOption "Blueprint framework for Pterodactyl panel";

    webUser = mkOption {
      type = types.str;
      default = pterodactylCfg.user;
      description = "Web server user for Blueprint";
    };

    ownership = mkOption {
      type = types.str;
      default = "${pterodactylCfg.user}:${pterodactylCfg.group}";
      description = "File ownership for Blueprint files";
    };

    userShell = mkOption {
      type = types.str;
      default = "/bin/bash";
      description = "Shell for the web user";
    };
  };

  config = mkIf (pterodactylCfg.enable && cfg.enable) {
    environment.systemPackages = [pkgs.blueprint];

    systemd.services.pterodactyl-blueprint = {
      description = "Blueprint framework for Pterodactyl panel";
      wantedBy = ["multi-user.target"];
      after = ["pterodactyl-panel.service"];
      path = with pkgs; [nodejs yarn zip unzip git curl wget];

      script = ''
        # Create .blueprintrc configuration
        cat > ${pterodactylCfg.dataDir}/.blueprintrc << EOF
        WEBUSER="${cfg.webUser}";
        OWNERSHIP="${cfg.ownership}";
        USERSHELL="${cfg.userShell}";
        EOF

        # Set ownership of the configuration file
        chown ${cfg.ownership} ${pterodactylCfg.dataDir}/.blueprintrc
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = pterodactylCfg.user;
        Group = pterodactylCfg.group;
        WorkingDirectory = pterodactylCfg.dataDir;
      };
    };
  };
}
