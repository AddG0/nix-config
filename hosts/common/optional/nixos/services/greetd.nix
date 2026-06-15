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
  config = {
    services.greetd = {
      enable = true;

      restart = true;
      settings = {
        # tuigreet is the fallback greeter, set at mkOptionDefault (weaker than
        # mkDefault) so any imported greeter module (e.g. noctalia-greeter,
        # whose command is at mkDefault) wins without touching this file.
        default_session = {
          command = lib.mkOptionDefault "${pkgs.tuigreet}/bin/tuigreet --asterisks --remember --time --time-format '%I:%M %p | %a • %h | %F' --cmd '${cfg.sessionCommand}'";
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
