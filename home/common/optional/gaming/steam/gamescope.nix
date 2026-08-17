# Builds a gamescope prefix for Steam's wrappers.
# Laptops resolve the target output at launch via hyprctl; desktops bake the
# declared primary at build. Neither re-checks mid-game. Set GAMESCOPE_OUTPUT to
# a connector name to override. Opt in per-game:
# wrappers = [gamemoderun] ++ gamescope;
# Skip for: anti-cheat (EAC), games needing the Steam overlay,
# PROTON_ENABLE_WAYLAND=1 titles, and games you want to tile freely.
#
# `env -u WAYLAND_DISPLAY` was previously prepended to each wrapper list: it hid
# the Wayland socket so gamescope used the SDL/Xwayland backend instead of its
# nested Wayland backend, dodging a wineserver hang on exit (leaked outer
# socket, gamescope#1396). Removed — the Wayland backend renders correctly,
# while SDL freezes-until-resize on Hyprland+NVIDIA. To restore, prepend to each
# branch's list below:  "env" "-u" "WAYLAND_DISPLAY"
{
  lib,
  pkgs,
  hyprctl,
  isLaptop,
  primaryMonitor,
  monitors,
  hdrArgs,
}: {extraArgs ? []}:
if isLaptop
then let
  # HDR has to follow the output actually resolved, not the declared primary.
  hdrCase = lib.concatMapStringsSep "\n" (m: ''
    ${m.output}) hdr_args=(${lib.escapeShellArgs (lib.optionals m.hdr ["--hdr-enabled"])}) ;;'')
  monitors;

  launcher = pkgs.writeShellApplication {
    name = "gamescope-output";
    runtimeInputs = [pkgs.gamescope pkgs.jq];
    text = ''
      primary=${lib.escapeShellArg primaryMonitor.output}
      W=${toString primaryMonitor.width}
      H=${toString primaryMonitor.height}
      R=${toString primaryMonitor.refreshRate}

      log() { printf 'gamescope-output: %s\n' "$*" >&2; }

      # Steam's runtime LD_LIBRARY_PATH shadows libstdc++ and breaks nix binaries
      # (hyprctl: GLIBCXX_3.4.35 not found); restored on exec for the game's preloads.
      steam_env=()
      [ -z "''${LD_LIBRARY_PATH:-}" ] || steam_env+=("LD_LIBRARY_PATH=$LD_LIBRARY_PATH")
      [ -z "''${LD_PRELOAD:-}" ] || steam_env+=("LD_PRELOAD=$LD_PRELOAD")
      unset LD_LIBRARY_PATH LD_PRELOAD

      hdr_for() {
        case "$1" in
      ${hdrCase}
          *)
            log "output $1 is not declared in display.monitors; assuming $primary's HDR setting"
            hdr_args=(${lib.escapeShellArgs hdrArgs})
            ;;
        esac
      }

      mons=$("${hyprctl}" monitors -j) || mons=""
      if [ -z "$mons" ]; then
        log "hyprctl monitors failed; falling back to declared primary $primary"
      fi

      target=""
      if [ -n "''${GAMESCOPE_OUTPUT:-}" ]; then
        target=$GAMESCOPE_OUTPUT
        log "GAMESCOPE_OUTPUT overrides output selection: $target"
      elif [ -n "$mons" ]; then
        # The active workspace's monitor is where the window lands; .focused can disagree.
        target=$("${hyprctl}" activeworkspace -j | jq -r '.monitor // empty') || target=""
        if [ -z "$target" ]; then
          target=$(jq -r 'map(select(.focused))[0].name // empty' <<<"$mons")
          log "active workspace's monitor unavailable; using focused monitor instead"
        fi
      fi
      [ -n "$target" ] || target=$primary

      if [ -n "$mons" ]; then
        mode=$(jq -r --arg n "$target" \
          'map(select(.name == $n))[0] // empty | "\(.width) \(.height) \(.refreshRate | round)"' \
          <<<"$mons") || mode=""
        if [ -n "$mode" ]; then
          read -r W H R <<<"$mode"
        else
          log "output $target not present in hyprctl monitors; falling back to declared primary $primary"
          target=$primary
        fi
      fi

      hdr_for "$target"
      log "output=$target mode=''${W}x''${H}@''${R} extra=''${hdr_args[*]:-none}"

      exec env "''${steam_env[@]}" \
        gamescope -W "$W" -H "$H" -w "$W" -h "$H" -r "$R" -f \
        ''${hdr_args[@]+"''${hdr_args[@]}"} ${lib.escapeShellArgs extraArgs} -- "$@"
    '';
  };
in [(lib.getExe launcher)]
else
  [
    (lib.getExe pkgs.gamescope)
    "-W"
    (toString primaryMonitor.width)
    "-H"
    (toString primaryMonitor.height)
    "-w"
    (toString primaryMonitor.width)
    "-h"
    (toString primaryMonitor.height)
    "-r"
    (toString primaryMonitor.refreshRate)
    "-f"
  ]
  ++ hdrArgs
  ++ extraArgs
  ++ ["--"]
