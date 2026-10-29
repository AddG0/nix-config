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
  dm = config.services.displayManager;
  # greetd ignores defaultSession and autoLogin, so they reach it as a start-session command.
  session = dm.sessionData.autologinSession;
  sessionCommand = "${lib.getExe config.desktops.startSession} ${session}";
in {
  config = {
    assertions = [
      {
        assertion = session != null;
        message = "greetd: no session to log into; import a desktop or Gaming Mode, which register one under desktops.sessions.";
      }
    ];

    # Type=idle holds ExecStart until the job queue drains, capped at 5s -- it keeps
    # a greeter off the console mid-boot, which autologin to a compositor doesn't need.
    systemd.services.greetd.serviceConfig.Type = lib.mkForce (
      if dm.autoLogin.enable
      then "simple"
      else "idle"
    );

    services.greetd = {
      enable = true;

      restart = true;
      settings = {
        # tuigreet is the fallback greeter, set at mkOptionDefault (weaker than
        # mkDefault) so any imported greeter module (e.g. noctalia-greeter,
        # whose command is at mkDefault) wins without touching this file.
        default_session = {
          command = lib.mkOptionDefault "${pkgs.tuigreet}/bin/tuigreet --asterisks --remember --time --time-format '%I:%M %p | %a • %h | %F' --cmd '${sessionCommand}'";
          user = config.hostSpec.primaryUsername;
        };

        initial_session = lib.mkIf dm.autoLogin.enable {
          command = sessionCommand;
          inherit (dm.autoLogin) user;
        };
      };
    };
  };
}
