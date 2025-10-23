#
# greeter -> tuigreet https://github.com/apognu/tuigreet?tab=readme-ov-file
# display manager -> greetd https://man.sr.ht/~kennylevinsen/greetd/
#
{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.greetd;
in {
  options.services.greetd = {
    sessionCommand = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.hyprland}/bin/Hyprland";
      description = "Command to run for session";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = config.hostSpec.username;
      description = "Username for greetd session";
    };

    autoLogin = {
      enable = lib.mkEnableOption "Enable automatic login";

      username = lib.mkOption {
        type = lib.types.str;
        default = config.services.greetd.username;
        description = "User to automatically login";
      };
    };
  };

  config = {
    services.greetd = {
      enable = true;

      restart = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --asterisks --time --time-format '%I:%M %p | %a • %h | %F' --cmd ${cfg.sessionCommand}";
          user = cfg.username;
        };

        initial_session = lib.mkIf cfg.autoLogin.enable {
          command = cfg.sessionCommand;
          user = cfg.autoLogin.username;
        };
      };
    };
  };
}
