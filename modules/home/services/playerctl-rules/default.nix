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
      inherit (cfg) package debug;
      audioTools = [pkgs.pulseaudio pkgs.jq];
    };
in {
  options.services.playerctlRules = {
    enable = lib.mkEnableOption "run an action on MPRIS tracks whose metadata matches a pattern (case-insensitive)";

    debug = lib.mkEnableOption "verbose logging of every follow event, match decision, and skip poll to the service journal";

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
                What to do on a match. "mute" mutes the player's audio stream
                while a matching track plays. "next" and "previous" mute it too,
                then skip; if the player ignores the skips, the track stays muted
                until it ends. pause, stop and play-pause fire once per matching
                track. Ignored if `command` is set (for non-mute actions).
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

            announcedTrack = lib.mkOption {
              type = lib.types.nullOr (lib.types.submodule {
                options = {
                  from = lib.mkOption {
                    type = lib.types.str;
                    description = "Part of a matching track's mpris:trackid that marks it as announcing a track.";
                  };
                  to = lib.mkOption {
                    type = lib.types.str;
                    description = "What `from` becomes in the announced track's trackid; the rest of the id is shared.";
                  };
                };
              });
              default = null;
              description = ''
                For players whose matching track introduces the next one: the
                announced track's trackid is the matching track's with `from`
                swapped for `to`. If a skip carries past it, the watcher presses
                Previous to land on it, still muted. A trackid whose id is all
                zeros announces nothing. Only for action = "next".
              '';
              example = lib.literalExpression ''
                {
                  # Spotify DJ X: "Up next" /media/<id> announces /track/<id>.
                  from = "/media/";
                  to = "/track/";
                }
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
        {
          assertion = pcfg.announcedTrack == null || (pcfg.action == "next" && pcfg.command == null);
          message = "services.playerctlRules.players.${player}: announcedTrack only applies to action = \"next\" without a custom `command`.";
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
