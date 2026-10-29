# greetd for the greeter modules that import it; each sets default_session.command. https://man.sr.ht/~kennylevinsen/greetd/
{
  config,
  lib,
  ...
}: let
  dm = config.services.displayManager;
  # greetd ignores defaultSession and autoLogin, so they reach it as a start-session command.
  session = dm.sessionData.autologinSession;
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
        default_session.user = config.hostSpec.primaryUsername;

        initial_session = lib.mkIf dm.autoLogin.enable {
          command = "${lib.getExe config.desktops.startSession} ${session}";
          inherit (dm.autoLogin) user;
        };
      };
    };
  };
}
