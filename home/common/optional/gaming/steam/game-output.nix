# Outermost Steam wrapper: resolves the output a game will land on once, at
# launch, and exports GAME_OUTPUT_{W,H,R,HDR} for the wrappers inside it
# (hdr-env, gamescope). GAME_OUTPUT_OVERRIDE=<connector> skips detection.
{
  lib,
  pkgs,
  hyprctl,
  monitors,
  primaryMonitor,
}: let
  hdrCase =
    lib.concatMapStrings (m: ''
      ${m.output}) hdr=${
        if m.hdr
        then "1"
        else "0"
      } ;;
    '')
    monitors;
in
  lib.getExe (pkgs.writeShellApplication {
    name = "game-output";
    runtimeInputs = [pkgs.jq];
    text = ''
      # Inside the gamescope session, its own gamescope picks the output and HDR.
      [ -z "''${GAMESCOPE_WAYLAND_DISPLAY:-}" ] || exec "$@"
      log() { printf 'game-output: %s\n' "$*" >&2; }

      # Steam's runtime LD_LIBRARY_PATH shadows libstdc++ and breaks hyprctl
      # (GLIBCXX_3.4.35 not found); restored on exec for the game's preloads.
      steam_env=()
      [ -z "''${LD_LIBRARY_PATH:-}" ] || steam_env+=("LD_LIBRARY_PATH=$LD_LIBRARY_PATH")
      [ -z "''${LD_PRELOAD:-}" ] || steam_env+=("LD_PRELOAD=$LD_PRELOAD")
      unset LD_LIBRARY_PATH LD_PRELOAD

      target=${lib.escapeShellArg primaryMonitor.output}
      W=${toString primaryMonitor.width}
      H=${toString primaryMonitor.height}
      R=${toString primaryMonitor.refreshRate}

      if mons=$("${hyprctl}" monitors -j); then
        want=''${GAME_OUTPUT_OVERRIDE:-}
        # The active workspace's monitor is where the window lands; .focused can disagree.
        [ -n "$want" ] || want=$("${hyprctl}" activeworkspace -j | jq -r '.monitor // empty') || want=""
        if mode=$(jq -er --arg n "$want" '
            (if $n == "" then map(select(.focused)) else map(select(.name == $n)) end)[0] // empty
            | "\(.name) \(.width) \(.height) \(.refreshRate | round)"' <<<"$mons"); then
          read -r target W H R <<<"$mode"
        else
          log "output '$want' not found; using declared primary $target"
        fi
      else
        log "hyprctl monitors failed; using declared primary $target"
      fi

      case "$target" in
      ${hdrCase}
        *)
          log "output $target is not declared in display.monitors; assuming SDR"
          hdr=0
          ;;
      esac

      log "output=$target mode=''${W}x''${H}@''${R} hdr=$hdr"
      exec env "''${steam_env[@]}" \
        GAME_OUTPUT_W="$W" GAME_OUTPUT_H="$H" GAME_OUTPUT_R="$R" GAME_OUTPUT_HDR="$hdr" "$@"
    '';
  })
