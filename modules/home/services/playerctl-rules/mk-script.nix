# Builds the watcher script for a single player. Pure (no module/config
# dependency) so it can be exercised directly from tests.nix with a stub
# playerctl. `package` only seeds the script's PATH via runtimeInputs.
{
  lib,
  writeShellApplication,
  package,
  player,
  pcfg,
  debug ? false,
}: let
  pc = "playerctl --player=${player}";
  isMute = pcfg.action == "mute";

  # A stderr line (visible in the service journal), compiled out unless debug.
  dbg = msg: lib.optionalString debug ''echo "playerctl-rule-dbg[$PLAYER]: ${msg}" >&2'';

  # Append the trackid to the watched format: playerctl --follow suppresses
  # repeats of identical output, so two back-to-back tracks with the same
  # artist/title (e.g. Spotify's "DJ X - Up next" segments) would collapse into
  # one event. The trackid keeps them distinct; it is stripped before matching.
  followFmt = "${pcfg.format}\t{{mpris:trackid}}";

  # One-shot: command override, else the action name as a playerctl verb.
  onMatch =
    if pcfg.command != null
    then pcfg.command
    else "${pc} ${pcfg.action}";

  # Held mute defaults to the player's own MPRIS volume (save then restore);
  # `command`/`unmuteCommand` override it for true stream muting (e.g. pactl).
  muteCmd =
    if pcfg.command != null
    then pcfg.command
    else ''
      saved=$(${pc} volume 2>/dev/null || true)
      ${pc} volume 0 || true
    '';
  unmuteCmd =
    if pcfg.unmuteCommand != null
    then pcfg.unmuteCommand
    else ''if [ -n "''${saved:-}" ]; then ${pc} volume "$saved" || true; fi'';

  # Mute is stateful: remember whether we muted, and always unmute on exit.
  prelude = lib.optionalString isMute ''
    muted=false
    saved=""
    do_mute() { ${muteCmd}
    }
    do_unmute() { ${unmuteCmd}
    }
    cleanup() { if [ "$muted" = true ]; then do_unmute; fi; }
    trap cleanup EXIT INT TERM
  '';

  # Skips re-read metadata after each `next`: a DJ X moment is often two segments
  # (recap, then up-next) with identical metadata, so the react block keeps
  # skipping while the settled track still matches and stops on the first real
  # song — one skip alone would leave the second segment playing.
  isSkip = pcfg.command == null && lib.elem pcfg.action ["next" "previous"];

  react =
    if isMute
    then ''
      if [ "$want" = true ] && [ "$muted" = false ]; then
        log "muting on \"$line\""
        do_mute
        muted=true
      elif [ "$want" = false ] && [ "$muted" = true ]; then
        log "unmuting"
        do_unmute
        muted=false
      fi
    ''
    else if isSkip
    then ''
      # $tid keys the segment; --follow replays the transitions we skip through
      # below as fresh events, so ignore any we have already acted on.
      if [ "$want" = true ]; then
        tid=''${raw#*$'\t'}
        if [ -n "''${skipped[$tid]:-}" ]; then
          ${dbg "already skipped [$tid]; ignoring buffered event"}
          continue
        fi
        skipped[$tid]=1
        log "skipping \"$line\""
        ${pc} ${pcfg.action} || true
        # A DJ X moment is often two segments (recap, then up-next) that carry
        # IDENTICAL metadata, so "did the track change" can't catch the hop from
        # one to the next. Instead keep skipping while the settled track still
        # matches, stopping on the first non-matching (real) song. Each settle
        # polls ~0.4s so the read reflects the skip (metadata updates within
        # ~200ms except right after Spotify launches); the segment count is
        # bounded so a cold-start lag can't run away skipping real songs.
        for ((n = 1; n <= 3; n++)); do
          now=""
          for ((i = 1; i <= 4; i++)); do
            sleep 0.1
            r=$(${pc} metadata --format ${lib.escapeShellArg followFmt} 2>/dev/null || true)
            if [ -n "$r" ]; then now=$r; fi
          done
          if [ -z "$now" ]; then break; fi
          if ! matches "''${now%%$'\t'*}"; then
            ${dbg "landed on real audio after $n poll(s): now=[$now]"}
            break
          fi
          ${dbg "still on a DJ segment [$now]; skipping again"}
          skipped[''${now#*$'\t'}]=1
          log "skipping \"''${now%%$'\t'*}\""
          ${pc} ${pcfg.action} || true
        done
      fi
    ''
    else ''
      if [ "$want" = true ]; then
        log "acting on \"$line\""
        { ${onMatch}; } || true
      fi
    '';
in
  writeShellApplication {
    name = "playerctl-rule-${player}";
    runtimeInputs = [package];
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
      ${prelude}${lib.optionalString isSkip "declare -A skipped=()"}
      ${dbg "started; patterns=[\${patterns[*]}] action=${pcfg.action} format=[${followFmt}]"}
      # $line = the matched metadata (trackid stripped); $want = whether it matches.
      while IFS= read -r raw; do
        line=''${raw%%$'\t'*}
        want=false
        if matches "$line"; then want=true; fi
        ${dbg "event: raw=[$raw] line=[$line] want=$want"}
        ${react}
      done < <(${pc} --follow --format ${lib.escapeShellArg followFmt} metadata)
    '';
  }
