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
    enable = mkEnableOption "Enable Blueprint framework for Pterodactyl panel";

    webUser = mkOption {
      type = types.str;
      default = "www-data";
      description = "Web server user for Blueprint";
    };

    ownership = mkOption {
      type = types.str;
      default = "www-data:www-data";
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

    systemd.services.blueprint-setup = {
      description = "Setup Blueprint for Pterodactyl Panel";
      after = ["pterodactyl-panel-setup.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        User = pterodactylCfg.user;
        Group = pterodactylCfg.group;
        WorkingDirectory = pterodactylCfg.dataDir;
      };
      script = ''
        # Create .blueprintrc configuration
        cat > .blueprintrc <<EOF
        WEBUSER="${cfg.webUser}";
        OWNERSHIP="${cfg.ownership}";
        USERSHELL="${cfg.userShell}";
        EOF

        # Copy Blueprint files to panel directory
        cp -r ${pkgs.blueprint}/* .
        chmod +x blueprint.sh

        # Run Blueprint setup
        ./blueprint.sh
      '';
    };
  };
}
