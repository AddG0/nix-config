{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.security.allow-poweroff;
in {
  options.security.allow-poweroff = {
    enable = mkEnableOption "Remote poweroff capability for user";

    user = mkOption {
      type = types.str;
      default = config.hostSpec.username;
      description = "User allowed to run poweroff command";
    };
  };

  config = mkIf cfg.enable {
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.login1.power-off" &&
            subject.user == "${cfg.user}") {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
