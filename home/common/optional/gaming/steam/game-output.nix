# Outermost Steam wrapper: exports GAME_OUTPUT_{W,H,R,HDR} of the output a game lands on, for gamescope inside it.
{
  lib,
  pkgs,
  focusedOutput,
  monitors,
  primaryMonitor,
}: let
  hdrCase =
    lib.concatMapStrings (m: ''
      ${lib.escapeShellArg m.output}) hdr=${
        if m.hdr
        then "1"
        else "0"
      } ;;
    '')
    monitors;
in
  lib.getExe (pkgs.writeShellApplication {
    name = "game-output";
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

      output=${lib.escapeShellArg primaryMonitor.output}
      W=${toString primaryMonitor.width}
      H=${toString primaryMonitor.height}
      R=${toString primaryMonitor.refreshRate}

      if focused=$("${focusedOutput}"); then
        read -r output W H R <<<"$focused"
      else
        log "using declared primary $output"
      fi

      case "$output" in
      ${hdrCase}
        *)
          log "output $output is not declared in display.monitors; assuming SDR"
          hdr=0
          ;;
      esac

      log "output=$output mode=''${W}x''${H}@''${R} hdr=$hdr"
      exec env "''${steam_env[@]}" \
        GAME_OUTPUT_W="$W" GAME_OUTPUT_H="$H" GAME_OUTPUT_R="$R" GAME_OUTPUT_HDR="$hdr" "$@"
    '';
  })
