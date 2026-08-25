# Keeps the server warm so opening a client costs a page load, not a server boot:
# readiness waits on the initial provider probes, and codex and opencode each
# take 1.5-2.5s of that.
#
# The desktop app has no attach mode — it forks its own backend — so a host
# running both ends up with two servers over one ~/.t3/userdata: state.sqlite is
# WAL and safe, but server-runtime.json holds a single record, so `t3 pair`
# discovery follows whichever started last. The app is pinned off this port in
# overlays/common/development/t3code.nix.
#
# Don't run `t3 service install` either; its unit self-updates from npm.
#
# On hosts nobody logs into, pair with
# hosts/common/optional/nixos/services/user-linger.nix.
{
  config,
  lib,
  ...
}: let
  cfg = config.services.t3codeServer;
in {
  options.services.t3codeServer = {
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Interface to bind. Reaching it from another machine means a tailnet
        address or an opened port, neither of which this module assumes.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3773;
      description = ''
        Port to serve on. Keep it stable per host: the client keeps its theme
        and UI state in localStorage keyed by origin, so a moving port orphans
        both.
      '';
    };
  };

  config = {
    systemd.user.services.t3code = {
      Unit = {
        Description = "T3 Code server";
        # A user unit cannot order against a system target, so waiting for the
        # network is the restart loop's job — these just bound it.
        StartLimitIntervalSec = 300;
        StartLimitBurst = 5;
      };

      Service = {
        Type = "simple";
        WorkingDirectory = config.home.homeDirectory;
        ExecStart = "${lib.getExe' config.programs.t3code.package "t3"} serve --host ${cfg.host} --port ${toString cfg.port}";
        Restart = "always";
        RestartSec = 5;
      };

      # Not graphical-session.target: the point is to outlive and precede any
      # session.
      Install.WantedBy = ["default.target"];
    };
  };
}
