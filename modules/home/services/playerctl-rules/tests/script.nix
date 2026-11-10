# Runs the REAL watcher from mk-script.nix against stand-ins for playerctl and
# pactl that replay Spotify DJ X sessions copied from real logs. The cases are
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
    announcedTrack = null;
  };

  # The rule from home/primary/common/core/playerctl-rules.nix.
  spotifyScript = mkScript (basePcfg
    // {
      announcedTrack = {
        from = "/media/";
        to = "/track/";
      };
    });
  # The same skip without Spotify's announced-track rule, as any other player gets it.
  plainSkipScript = mkScript basePcfg;
  muteScript = mkScript (basePcfg // {action = "mute";});

  # Stand-in for playerctl, playing the queue in $STATES (one "<title>\t<trackid>" row each):
  #   --follow      -> print $FOLLOW_FIXTURE, the events the watcher reacts to, then exit
  #   metadata      -> the row at $POS; for $LAGSTEPS reads after a skip, still the row before it ($SPOS)
  #   next/previous -> record the verb and move $POS by `step`; while $DROP > 0, record but ignore it
  # /media/<id> rows are DJ X segments; "Up next" announces the /track/<id> after it.
  stub = pkgs.writeShellScriptBin "playerctl" ''
    id_at() { local r; r=$(sed -n "$(($1 + 1))p" "$STATES"); echo "''${r#*$'\t'}"; }
    step() {
      local pos=$1 verb=$2 cur to
      cur=$(id_at "$pos")
      if [ "$verb" = next ]; then
        to=$((pos + 1))
        # Next on "Up next" either skips the song it announces too or lands on it.
        if [ "''${NEXT_ON_UP_NEXT:-skips-announced}" = skips-announced ] && [[ "$cur" == */media/* && "$(id_at "$to")" == */track/"''${cur##*/media/}" ]]; then to=$((to + 1)); fi
        # A DJ segment plays once; Next passes over one already left.
        if grep -qx "$to" "$CONSUMED" 2>/dev/null; then to=$((to + 1)); fi
      else
        to=$((pos - 1))
        # Previous never re-enters a DJ segment; it restarts the song instead.
        if [ "$to" -lt 0 ] || [[ "$(id_at "$to")" == */media/* ]]; then to=$pos; fi
      fi
      if [[ "$cur" == */media/* && "$to" != "$pos" ]]; then echo "$pos" >>"$CONSUMED"; fi
      echo "$to"
    }

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
      next | previous | pause | stop | play-pause)
        echo "$last" >>"$ACTIONS"
        drops=$(cat "$DROP" 2>/dev/null || echo 0)
        if [ "$drops" -gt 0 ]; then
          echo "$((drops - 1))" >"$DROP"
        else
          pos=$(cat "$POS" 2>/dev/null || echo 0)
          echo "$pos" >"$SPOS"
          if [ "$last" = previous ]; then to=$(step "$pos" previous); else to=$(step "$pos" next); fi
          echo "$to" >"$POS"
          if [ "''${LAGSTEPS:-0}" -gt 0 ]; then echo "$LAGSTEPS" >"$LAG"; fi
        fi
        ;;
    esac
    exit 0
  '';

  # Stand-in for pactl: $LOCAL=1 reports an uncorked spotify stream on this host;
  # anything else reports it corked, as on a Connect client mirroring another device.
  # The first $CORK reads report corked anyway, as Spotify does across a track change.
  # `set-sink-input-mute <index> 1|0` records "stream muted" / "stream unmuted".
  pactlStub = pkgs.writeShellScriptBin "pactl" ''
    if [ "$1" = set-sink-input-mute ]; then
      if [ "$3" = 1 ]; then echo "stream muted" >>"$ACTIONS"; else echo "stream unmuted" >>"$ACTIONS"; fi
      exit 0
    fi
    corked=true
    if [ "''${LOCAL:-1}" = 1 ]; then corked=false; fi
    cork=$(cat "$CORK" 2>/dev/null || echo 0)
    if [ "$cork" -gt 0 ]; then
      echo "$((cork - 1))" >"$CORK"
      corked=true
    fi
    echo '[{"index":1,"corked":'"$corked"',"properties":{"application.name":"spotify"}}]'
  '';

  queue = name: rows: pkgs.writeText name (lib.concatMapStrings (r: r + "\n") rows);

  # Made-up songs: real titles and trackids would publish listening history.
  # A Spotify trackid's id is 22 characters; DJ X segments use /media/, songs /track/.
  id = name: lib.fixedWidthString 22 "0" name;
  song = title: name: "${title}\t/com/spotify/track/${id name}";
  upNext = name: "DJ X - Up next\t/com/spotify/media/${id name}";
  welcome = "DJ X - Welcome\t/com/spotify/media/${id ""}";

  songBefore = song "Song Before - Played Last" "SongBefore";
  announcedSong = song "Announced Song - DJ Pick" "AnnouncedSong";
  songAfter = song "Song After - Skipped Past" "SongAfter";
  firstSong = song "First Song - After Welcome" "FirstSong";

  # An Up next segment, the song it announces, then the next song.
  upNextQueue = queue "up-next-queue" [songBefore (upNext "AnnouncedSong") announcedSong songAfter];
  upNextFollow = queue "up-next-follow" [(upNext "AnnouncedSong")];

  # A Welcome (every one has the all-zero id) announces no song.
  welcomeQueue = queue "welcome-queue" [songBefore welcome firstSong songAfter];
  welcomeFollow = queue "welcome-follow" [welcome];

  # Two Welcomes hours apart, both with the all-zero id.
  reusedIdFollow = queue "reused-id-follow" [welcome firstSong welcome];
  reusedIdQueue = queue "reused-id-queue" [welcome firstSong songAfter];

  # Two Up next segments back to back (rare: once in two weeks).
  backToBackQueue = queue "back-to-back-queue" [
    (upNext "FirstAnnounced")
    (upNext "AnnouncedSong")
    announcedSong
    songAfter
  ];
  backToBackFollow = queue "back-to-back-follow" [(upNext "FirstAnnounced") (upNext "AnnouncedSong")];

  # Spotify ignores the first Next (72 of 74 re-skips in two weeks looked like this).
  ignoredSkipQueue = queue "ignored-skip-queue" [(upNext "AnnouncedSong") announcedSong songAfter];
  ignoredSkipFollow = queue "ignored-skip-follow" [(upNext "AnnouncedSong")];

  # Spotify refuses all four skips, so the segment played out into its song.
  refusedSkipsFollow = queue "refused-skips-follow" [(upNext "AnnouncedSong") announcedSong];

  # The Welcome retitles itself "Up next" under the same id, then a song.
  muteFollow = queue "mute-follow" [
    songBefore
    welcome
    "DJ X - Up next\t/com/spotify/media/${id ""}"
    firstSong
  ];
in
  harness.bats "playerctl-rules-test" [./playerctl-rules.bats] {
    spotifyScript = lib.getExe spotifyScript;
    plainSkipScript = lib.getExe plainSkipScript;
    muteScript = lib.getExe muteScript;
    playerctl = "${stub}/bin/playerctl";
    inherit upNextQueue upNextFollow welcomeQueue welcomeFollow reusedIdQueue reusedIdFollow;
    inherit backToBackQueue backToBackFollow ignoredSkipQueue ignoredSkipFollow refusedSkipsFollow muteFollow;
  }
