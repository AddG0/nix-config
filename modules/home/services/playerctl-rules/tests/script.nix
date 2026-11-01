# Behavioral tests for the playerctl-rules watcher script. Runs the REAL script
# produced by mk-script.nix against a stub `playerctl` that simulates a player:
# `--follow` replays a trigger stream, `metadata` returns the current track
# (which advances as `next` is called), and actions are recorded. The cases are
# in ./playerctl-rules.bats.
{
  pkgs,
  lib,
  harness,
  ...
}: let
  mkScript = pcfg:
    import ../mk-script.nix {
      inherit lib pcfg;
      inherit (pkgs) writeShellApplication;
      package = stub;
      audioTools = [pactlStub pkgs.jq];
      player = "spotify";
    };

  basePcfg = {
    patterns = ["DJ X"];
    action = "next";
    command = null;
    unmuteCommand = null;
    format = "{{artist}} - {{title}}";
  };

  skipScript = mkScript basePcfg;
  muteScript = mkScript (basePcfg // {action = "mute";});

  # Stand-in for playerctl:
  #   --follow      -> replay $FOLLOW_FIXTURE (the trigger stream), then exit
  #   metadata      -> print the current line of $STATES. Models Spotify's MPRIS
  #                    lag: after a skip, $LAGSTEPS metadata reads keep returning
  #                    the pre-skip row ($SPOS) before catching up to $POS.
  #   next/previous -> record the verb and advance the $POS cursor into $STATES,
  #                    unless $DROP > 0 (record but ignore, simulating Spotify
  #                    dropping a skip at a segment boundary), decrementing $DROP
  #   volume        -> bare = query (0.7); with a value = record VOLUME=<value>
  stub = pkgs.writeShellScriptBin "playerctl" ''
    if [[ "$*" == *--follow* ]]; then
      cat "$FOLLOW_FIXTURE"
      exit 0
    fi
    if [[ "$*" == *metadata* ]]; then
      lag=$(cat "$LAG" 2>/dev/null || echo 0)
      if [ "$lag" -gt 0 ]; then
        echo "$((lag - 1))" >"$LAG"
        p=$(cat "$SPOS" 2>/dev/null || echo 0)
      else
        p=$(cat "$POS" 2>/dev/null || echo 0)
      fi
      sed -n "$((p + 1))p" "$STATES"
      exit 0
    fi
    all="$*"
    last=''${all##* }
    case "$last" in
      volume) echo "0.7" ;;
      next | previous | pause | stop | play-pause)
        echo "$last" >>"$ACTIONS"
        drops=$(cat "$DROP" 2>/dev/null || echo 0)
        if [ "$drops" -gt 0 ]; then
          echo "$((drops - 1))" >"$DROP"
        else
          pos=$(cat "$POS" 2>/dev/null || echo 0)
          echo "$pos" >"$SPOS"
          echo "$((pos + 1))" >"$POS"
          if [ "''${LAGSTEPS:-0}" -gt 0 ]; then echo "$LAGSTEPS" >"$LAG"; fi
        fi
        ;;
      *) if [[ "$last" =~ ^[0-9.]+$ ]]; then echo "VOLUME=$last" >>"$ACTIONS"; fi ;;
    esac
    exit 0
  '';

  # Stand-in for pactl: $LOCAL=1 reports an uncorked spotify stream on this host;
  # anything else reports it corked, as on a Connect client mirroring another device.
  # The first $CORK reads report corked anyway, as Spotify does across a track change.
  pactlStub = pkgs.writeShellScriptBin "pactl" ''
    corked=true
    if [ "''${LOCAL:-1}" = 1 ]; then corked=false; fi
    cork=$(cat "$CORK" 2>/dev/null || echo 0)
    if [ "$cork" -gt 0 ]; then
      echo "$((cork - 1))" >"$CORK"
      corked=true
    fi
    echo '[{"index":1,"corked":'"$corked"',"properties":{"application.name":"spotify"}}]'
  '';

  # Skip trigger: two back-to-back DJ X segments then a real song, each its own
  # --follow event (distinct trackid) as real playerctl emits them. The first
  # event must skip THROUGH both segments to the song in one reaction (the poll
  # reads the second DJ segment from STATES and re-skips it); the replayed djx2
  # event must then be ignored, and the real song never skipped.
  skipFollow = pkgs.writeText "skip-follow" ''
    DJ X - Up next	/id/djx1
    DJ X - Up next	/id/djx2
    Real Artist - Real Song	/id/song1
  '';
  skipStates = pkgs.writeText "skip-states" ''
    DJ X - Up next	/id/djx1
    DJ X - Up next	/id/djx2
    Real Artist - Real Song	/id/song1
  '';

  # Retry trigger: a single DJ X event whose first skip is dropped (DROP=1). The
  # watcher must retry until the track leaves DJ X and land exactly on the song —
  # not over-skip past it.
  retryFollow = pkgs.writeText "retry-follow" ''
    DJ X - Up next	/id/djx1
  '';
  retryStates = pkgs.writeText "retry-states" ''
    DJ X - Up next	/id/djx1
    Real Artist - Real Song	/id/song1
  '';

  # Over-skip regression: a single DJ X event with a transient metadata lag
  # (3 stale reads) after the skip, as right after Spotify launches. The settle
  # poll must drain the stale reads and see the real song, so exactly one `next`
  # fires — it must not skip again on a stale DJ read and blow past the song.
  lagFollow = pkgs.writeText "lag-follow" ''
    DJ X - Welcome	/id/djx1
  '';
  lagStates = pkgs.writeText "lag-states" ''
    DJ X - Welcome	/id/djx1
    Real One - A	/id/s1
    Real Two - B	/id/s2
    Real Three - C	/id/s3
  '';

  # Mute trigger: the held-mute path reconciles directly off the follow stream
  # (trackid appended so the two DJ X rows are distinct events).
  muteFollow = pkgs.writeText "mute-follow" ''
    OR3O - Still Dancing	/id/song1
    DJ X - Up next	/id/djx1
    DJ X - Up next	/id/djx2
    Imagine - Clair de Lune	/id/song2
  '';
in
  harness.bats "playerctl-rules-test" [./playerctl-rules.bats] {
    skipScript = lib.getExe skipScript;
    muteScript = lib.getExe muteScript;
    inherit skipFollow skipStates retryFollow retryStates lagFollow lagStates muteFollow;
  }
