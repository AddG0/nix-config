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

  # Retry the skip: Spotify drops a `next` issued the instant a DJ segment starts
  # (exactly when --follow wakes us), so a single skip often no-ops.
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
      if [ "$want" = true ]; then
        log "skipping \"$line\""
        ${pc} ${pcfg.action} || true
        # A dropped next never fires, so breaking on the first change lands on the
        # announced song and can't stack skips onto later tracks.
        for ((i = 1; i <= 40; i++)); do
          sleep 0.1
          now=$(${pc} metadata --format ${lib.escapeShellArg followFmt} 2>/dev/null || true)
          if [ -n "$now" ] && [ "$now" != "$raw" ]; then
            ${dbg "skip took after $((i * 100))ms: now=[$now]"}
            break
          fi
          if ((i % 3 == 0)); then
            ${dbg "skip not taken after $((i * 100))ms; retrying"}
            ${pc} ${pcfg.action} || true
          fi
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
      ${prelude}
      ${dbg "started; patterns=[\${patterns[*]}] action=${pcfg.action} format=[${followFmt}]"}
      # $line = the matched metadata (trackid stripped); $want = whether it matches.
      while IFS= read -r raw; do
        line=''${raw%%$'\t'*}
        want=false
        for pat in "''${patterns[@]}"; do
          if [[ -n "$line" && "$line" == *"$pat"* ]]; then
            want=true
            break
          fi
        done
        ${dbg "event: raw=[$raw] line=[$line] want=$want"}
        ${react}
      done < <(${pc} --follow --format ${lib.escapeShellArg followFmt} metadata)
    '';
  }
