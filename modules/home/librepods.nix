{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.librepods;
  c = config.lib.stylix.colors.withHashtag;
in {
  options.programs.librepods = {
    enable = mkEnableOption "LibrePods - AirPods integration for Linux";

    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically start LibrePods on login";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.librepods;
      description = "LibrePods package to use";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [cfg.package];

    systemd.user.services.librepods = mkIf cfg.autoStart {
      Unit = {
        Description = "LibrePods - AirPods integration for Linux";
        After = ["bluetooth.target" "pipewire.service"];
        Wants = ["bluetooth.target"];
      };

      Service = {
        Type = "simple";
        # Unset QT_STYLE_OVERRIDE to prevent QML from trying to load kvantum
        # as a QML module. Use Universal style with Stylix colors instead.
        Environment = [
          "QT_STYLE_OVERRIDE="
          "QT_QUICK_CONTROLS_STYLE=Universal"
          "QT_QUICK_CONTROLS_UNIVERSAL_THEME=Dark"
          "QT_QUICK_CONTROLS_UNIVERSAL_ACCENT=${c.base0D}"
          "QT_QUICK_CONTROLS_UNIVERSAL_BACKGROUND=${c.base00}"
          "QT_QUICK_CONTROLS_UNIVERSAL_FOREGROUND=${c.base05}"
        ];
        ExecStart = "${cfg.package}/bin/librepods --hide";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
