# Builds the watcher script for a single player. Pure (no module/config
# dependency) so tests/playerctl-rules.bats can run it directly with a stub
# playerctl. `package` and `audioTools` (pactl + jq) only seed the script's PATH.
{
  lib,
  writeShellApplication,
  package,
  audioTools,
  player,
  pcfg,
  debug ? false,
}: let
  pc = "playerctl --player=${player}";

  isMute = pcfg.action == "mute";
  isSkip = pcfg.command == null && lib.elem pcfg.action ["next" "previous"];
  # Mute and skip rules silence a matching track first; a skip that works only shortens the silence.
  holdsMute = isMute || isSkip;
  announces = isSkip && pcfg.announcedTrack != null;

  # Append the trackid to the watched format: playerctl --follow suppresses
  # repeats of identical output, so two back-to-back tracks with the same
  # artist/title (e.g. Spotify's "DJ X - Up next" segments) would collapse into
  # one event. The trackid keeps them distinct; it is stripped before matching.
  followFmt = "${pcfg.format}\t{{mpris:trackid}}";

  # A stderr line (visible in the service journal), compiled out unless debug.
  dbg = msg: lib.optionalString debug ''echo "playerctl-rule-dbg[$PLAYER]: ${msg}" >&2'';

  # Connect mirrors the active device's track into every client's MPRIS; act only where audio plays.
  # Polled up to 12s: after quick skips a DJ segment stays corked while loading (seen for 1.6s).
  localGate = ''
    playing_here() {
      local i r
      for ((i = 1; i <= 120; i++)); do
        pactl -f json list sink-inputs 2>/dev/null | jq -e --arg p "$PLAYER" \
          'any(.[]; .corked == false and (.properties["application.name"] // "" | ascii_downcase) == $p)' >/dev/null \
          && return 0
        if ((i % 5 == 0)); then
          r=$(${pc} metadata --format ${lib.escapeShellArg followFmt} 2>/dev/null || true)
          if [[ -n "$r" && "''${r#*$'\t'}" != "$1" ]]; then return 1; fi
        fi
        sleep 0.1
      done
      return 1
    }
  '';

  muteCmd =
    if isMute && pcfg.command != null
    then pcfg.command
    else "set_stream_mute 1";
  unmuteCmd =
    if isMute && pcfg.unmuteCommand != null
    then pcfg.unmuteCommand
    else "set_stream_mute 0";

  muteHelpers = ''
    # pactl's "Invalid non-ASCII" stderr is about other apps' stream titles.
    stream_ids() {
      pactl -f json list sink-inputs 2>/dev/null | jq -r --arg p "$PLAYER" \
        '.[] | select((.properties["application.name"] // "" | ascii_downcase) == $p) | .index'
    }
    set_stream_mute() {
      local i
      for i in $(stream_ids); do
        pactl set-sink-input-mute "$i" "$1" || log "could not set mute=$1 on audio stream $i"
      done
    }
    muted=false
    hold_mute() {
      if [ "$muted" = false ]; then
        log "muting while \"$1\" plays"
        ${muteCmd}
        muted=true
      fi
    }
    release_mute() {
      if [ "$muted" = true ]; then
        log "unmuting"
        ${unmuteCmd}
        muted=false
      fi
    }
    trap release_mute EXIT
    trap 'exit 143' INT TERM
  '';

  skipHelpers =
    ''
      declare -A skipped=()
      # Sets $now to the track after a skip, polling ~0.4s for MPRIS to catch up.
      settle() {
        local i r
        now=""
        for ((i = 1; i <= 4; i++)); do
          sleep 0.1
          r=$(${pc} metadata --format ${lib.escapeShellArg followFmt} 2>/dev/null || true)
          if [ -n "$r" ]; then now=$r; fi
        done
      }
      # $1 is a track's "<title>\t<trackid>".
      skip() {
        log "skipping \"''${1%%$'\t'*}\""
        ${pc} ${pcfg.action} || true
      }
    ''
    + lib.optionalString announces ''
      # Prints the trackid that track $1 announces: `from` swapped for `to`.
      # An all-zero id is a placeholder (Spotify's DJ X Welcome) and announces nothing.
      announced_track() {
        local from=${lib.escapeShellArg pcfg.announcedTrack.from} to=${lib.escapeShellArg pcfg.announcedTrack.to}
        if [[ "$1" != *"$from"* || "''${1##*/}" =~ ^0+$ ]]; then return 0; fi
        echo "''${1/"$from"/"$to"}"
      }
      # A skip can carry past the track segment $1 announced; Previous steps back onto it.
      return_to_announced() {
        local target
        target=$(announced_track "$1")
        if [[ -z "$target" || "''${now#*$'\t'}" == "$target" ]]; then return; fi
        log "returning to the announced track $target"
        ${pc} previous || true
        settle
        if [[ "''${now#*$'\t'}" != "$target" ]]; then
          log "previous landed on \"''${now%%$'\t'*}\", not the announced track $target"
        fi
      }
    '';

  # $tid keys the segment; --follow replays the transitions we skip through as
  # fresh events, so ignore any we have already acted on.
  skipMatch = ''
    tid=''${raw#*$'\t'}
    if [ -n "''${skipped[$tid]:-}" ]; then
      ${dbg "already skipped [$tid]; ignoring buffered event"}
      continue
    fi
    hold_mute "$line"
    skipped[$tid]=1
    skip "$raw"
    # The player can ignore a skip or queue segments back to back; capped so lag can't eat real songs.
    for ((n = 1; n <= 3; n++)); do
      settle
      if [ -z "$now" ]; then break; fi
      if ! matches "''${now%%$'\t'*}"; then
        ${dbg "landed on real audio after $n poll(s): now=[$now]"}
        ${lib.optionalString announces ''return_to_announced "$tid"''}
        break
      fi
      ${dbg "still on a matching track [$now]; skipping again"}
      tid=''${now#*$'\t'}
      skipped[$tid]=1
      skip "$now"
    done
    if [ -n "$now" ] && matches "''${now%%$'\t'*}"; then
      log "the player ignored every skip; staying muted until \"''${now%%$'\t'*}\" ends"
    else
      release_mute
    fi
  '';

  react =
    if holdsMute
    then ''
      if [ "$want" = true ]; then
        ${
        if isSkip
        then skipMatch
        else ''hold_mute "$line"''
      }
      else
        release_mute
        ${lib.optionalString isSkip ''
        # Replays precede the real track, and Spotify reuses trackids (every Welcome is /media/000…).
        skipped=()
      ''}
      fi
    ''
    else ''
      if [ "$want" = true ]; then
        log "acting on \"$line\""
        { ${
        if pcfg.command != null
        then pcfg.command
        else "${pc} ${pcfg.action}"
      }; } || true
      fi
    '';
in
  writeShellApplication {
    name = "playerctl-rule-${player}";
    runtimeInputs = [package] ++ audioTools;
    text = ''
      shopt -s nocasematch
      patterns=(${lib.concatMapStringsSep " " lib.escapeShellArg pcfg.patterns})
      export PLAYER=${player}
      log() { echo "playerctl-rule[$PLAYER]: $*"; }
      matches() {
        local s=$1 pat
        for pat in "''${patterns[@]}"; do
          [[ -n "$s" && "$s" == *"$pat"* ]] && return 0
        done
        return 1
      }
      ${localGate}${lib.optionalString holdsMute muteHelpers}${lib.optionalString isSkip skipHelpers}
      ${dbg "started; patterns=[\${patterns[*]}] action=${pcfg.action} format=[${followFmt}]"}
      ${lib.optionalString debug ''
        ${pc} --follow --format ${lib.escapeShellArg "{{status}}\t{{artist}} - {{title}}\t{{mpris:trackid}}"} metadata \
          | while IFS= read -r ev; do echo "playerctl-rule-dbg[$PLAYER]: player event: $ev" >&2; done &
      ''}
      # $line = the matched metadata (trackid stripped); $want = whether it matches here.
      while IFS= read -r raw; do
        line=''${raw%%$'\t'*}
        want=false
        if matches "$line" && playing_here "''${raw#*$'\t'}"; then want=true; fi
        ${dbg "event: raw=[$raw] line=[$line] want=$want"}
        ${react}
      done < <(${pc} --follow --format ${lib.escapeShellArg followFmt} metadata)
    '';
  }
