# Builds the watcher script for a single player. Pure (no module/config
# dependency) so it can be exercised directly from tests.nix with a stub
# playerctl. `package` only seeds the script's PATH via runtimeInputs.
{
  lib,
  writeShellApplication,
  package,
  player,
  pcfg,
}: let
  pc = "playerctl --player=${player}";
  isMute = pcfg.action == "mute";

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

  # Skip actions re-query the live title and repeat until it stops matching:
  # DJ-style intros (e.g. Spotify's "DJ X") come back-to-back, so a single
  # `next` lands on the next intro. Re-reading the real state (not the stale
  # follow line) also prevents over-skipping on events from our own skips.
  isSkip = pcfg.command == null && lib.elem pcfg.action ["next" "previous"];

  react =
    if isMute
    then ''
      if [ "$want" = true ] && [ "$muted" = false ]; then
        echo "playerctl-rule[$PLAYER]: muting on \"$line\""
        do_mute
        muted=true
      elif [ "$want" = false ] && [ "$muted" = true ]; then
        echo "playerctl-rule[$PLAYER]: unmuting"
        do_unmute
        muted=false
      fi
    ''
    else if isSkip
    then ''
      if [ "$want" = true ]; then
        attempts=0
        while [ "$attempts" -lt 12 ]; do
          cur=$(${pc} metadata --format ${lib.escapeShellArg pcfg.format} 2>/dev/null || true)
          hit=false
          for p in "''${patterns[@]}"; do
            if [[ -n "$cur" && "$cur" == *"$p"* ]]; then
              hit=true
              break
            fi
          done
          [ "$hit" = true ] || break
          echo "playerctl-rule[$PLAYER]: skipping \"$cur\""
          ${pc} ${pcfg.action} || true
          attempts=$((attempts + 1))
          sleep 0.4
        done
      fi
    ''
    else ''
      if [ "$want" = true ]; then
        echo "playerctl-rule[$PLAYER]: acting on \"$line\""
        { ${onMatch}; } || true
      fi
    '';
in
  writeShellApplication {
    name = "playerctl-rule-${player}";
    runtimeInputs = [package];
    # $line holds the player's metadata on each change, $want whether it matches.
    # trackid is appended to the followed format so back-to-back tracks with
    # identical artist/title (e.g. two "DJ X - Up next" segments) still emit an
    # event — playerctl --follow suppresses repeats of identical output — then
    # stripped before matching so patterns and logs only see the metadata.
    text = ''
      shopt -s nocasematch
      patterns=(${lib.concatMapStringsSep " " lib.escapeShellArg pcfg.patterns})
      export PLAYER=${player}
      ${prelude}
      while IFS= read -r raw; do
        line=''${raw%%$'\t'*}
        want=false
        for pat in "''${patterns[@]}"; do
          if [[ -n "$line" && "$line" == *"$pat"* ]]; then
            want=true
            break
          fi
        done
        ${react}
      done < <(${pc} --follow --format ${lib.escapeShellArg "${pcfg.format}\t{{mpris:trackid}}"} metadata)
    '';
  }
