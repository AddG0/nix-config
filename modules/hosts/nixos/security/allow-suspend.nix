{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.security.allow-suspend;
in {
  options.security.allow-suspend = {
    enable = mkEnableOption "Allow suspend/sleep without authentication";

    user = mkOption {
      type = types.str;
      default = config.hostSpec.username;
      description = "User allowed to suspend without authentication";
    };
  };

  config = mkIf cfg.enable {
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.login1.suspend" ||
             action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
             action.id == "org.freedesktop.login1.hibernate" ||
             action.id == "org.freedesktop.login1.hibernate-multiple-sessions") &&
            subject.user == "${cfg.user}") {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
