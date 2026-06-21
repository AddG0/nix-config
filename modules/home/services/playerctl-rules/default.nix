{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.playerctlRules;

  # Preset actions are passed straight through as playerctl subcommands;
  # "mute" is special-cased because it is held for the match's duration.
  oneShotActions = ["next" "previous" "pause" "stop" "play-pause"];
  allActions = oneShotActions ++ ["mute"];

  mkScript = player: pcfg:
    import ./mk-script.nix {
      inherit lib player pcfg;
      inherit (pkgs) writeShellApplication;
      inherit (cfg) package;
    };
in {
  options.services.playerctlRules = {
    enable = lib.mkEnableOption "run an action on MPRIS tracks whose metadata matches a pattern (case-insensitive)";

    package = lib.mkPackageOption pkgs "playerctl" {};

    players = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            patterns = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Substrings of the formatted metadata that trigger the action for this player.";
              example = ["DJ X"];
            };

            action = lib.mkOption {
              type = lib.types.enum allActions;
              default = "next";
              description = ''
                What to do on a match. One-shot actions (next, previous, pause,
                stop, play-pause) fire once per matching track. "mute" is held:
                the source is muted while a matching track plays and unmuted when
                it stops matching. Ignored if `command` is set (for non-mute actions).
              '';
            };

            command = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Custom shell command, overriding the preset. For one-shot actions
                it runs on each match; for action = "mute" it is the *mute* command
                (pair it with `unmuteCommand`). The matched metadata is available as
                `$line` and the player name as `$PLAYER`. Use absolute paths (e.g.
                interpolate `''${pkgs.pulseaudio}/bin/pactl`) — the service runs with
                a minimal PATH.
              '';
            };

            unmuteCommand = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Counterpart to `command` for action = "mute": run when a matching
                track stops matching, and on service exit. Required when a custom
                mute `command` is set, otherwise the source would stay muted.
              '';
            };

            format = lib.mkOption {
              type = lib.types.str;
              default = "{{artist}} - {{title}}";
              description = ''
                playerctl format string built into the haystack that patterns are
                matched against. Defaults to artist + title so e.g. Spotify's AI DJ
                (artist "DJ X") is caught regardless of the segment title.
              '';
            };
          };
        }
      );
      default = {};
      description = ''
        MPRIS players to watch, keyed by playerctl player name (e.g. "spotify").
        Each player is followed independently and runs its own action on a match.
      '';
      example = lib.literalExpression ''
        {
          spotify.patterns = ["DJ X"];                       # skip (default action)
          firefox = {
            patterns = ["Sponsored"];
            action = "mute";                                 # mute for the duration
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.flatten (
      lib.mapAttrsToList (player: pcfg: [
        {
          assertion = pcfg.action == "mute" || pcfg.unmuteCommand == null;
          message = "services.playerctlRules.players.${player}: unmuteCommand only applies when action = \"mute\".";
        }
        {
          assertion = !(pcfg.action == "mute" && pcfg.command != null && pcfg.unmuteCommand == null);
          message = "services.playerctlRules.players.${player}: a custom mute `command` requires a matching `unmuteCommand`, otherwise the source stays muted.";
        }
      ])
      cfg.players
    );

    systemd.user.services =
      lib.mapAttrs' (
        player: pcfg:
          lib.nameValuePair "playerctl-rule-${player}" {
            Unit = {
              Description = "Run configured action on matching ${player} tracks";
              After = ["graphical-session.target"];
              PartOf = ["graphical-session.target"];
            };

            Service = {
              ExecStart = lib.getExe (mkScript player pcfg);
              Restart = "always";
              RestartSec = 5;
            };

            Install.WantedBy = ["default.target"];
          }
      )
      cfg.players;
  };
}
