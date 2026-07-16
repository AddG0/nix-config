# Per-game mouse DPI. Returns `mouseDpi :: int -> wrappers list` that captures
# the baseline, sets the per-game value, runs the game, and restores on exit.
#
# Restore can't simply wait on the wrapped process: Proton games sit behind
# a launcher/anti-cheat (Overwatch's BattlEye belauncher, Battle.net, the EA
# app) that stays alive after the game window closes, so the wrapped process
# only returns much later. Steam points STEAM_COMPAT_INSTALL_PATH at the
# game's own files while the launcher lives in the wine prefix — so we watch
# the executables shipped with the game and restore when the last one exits.
# Native games have no such indirection, so we just wait on the process.
# Usage: `wrappers = mouseDpi 800 ++ [gamemoderun] ++ gamescope;`
{
  lib,
  pkgs,
  razerEnabled,
}: let
  # Print the D-Bus object path of the first openrazer device that supports
  # DPI control, or exit nonzero if no such device is connected.
  razerMousePath = pkgs.writeShellApplication {
    name = "razer-mouse-path";
    runtimeInputs = with pkgs; [glib gnugrep coreutils];
    text = ''
      serials=$(gdbus call --session --dest org.razer \
        --object-path /org/razer \
        --method razer.devices.getDevices 2>/dev/null) || exit 1
      for s in $(echo "$serials" | grep -oE "'[^']+'" | tr -d "'"); do
        if gdbus introspect --session --dest org.razer \
            --object-path "/org/razer/device/$s" 2>/dev/null \
            | grep -q "razer.device.dpi"; then
          echo "/org/razer/device/$s"
          exit 0
        fi
      done
      exit 1
    '';
  };
in
  dpi:
    lib.optionals razerEnabled [
      (lib.getExe (pkgs.writeShellApplication {
        name = "mouse-dpi-${toString dpi}";
        runtimeInputs = with pkgs; [glib coreutils findutils procps razerMousePath];
        text = ''
          set -u

          # No DPI-capable Razer mouse → just run the game untouched.
          if ! mouse_path=$(razer-mouse-path); then
            exec "$@"
          fi

          prev_file="''${XDG_STATE_HOME:-$HOME/.local/state}/gaming-mouse-dpi/prev"
          mkdir -p "$(dirname "$prev_file")"

          dpi_call() {
            local method=$1
            shift
            gdbus call --session --dest org.razer \
              --object-path "$mouse_path" --method "razer.device.dpi.$method" "$@" 2>/dev/null
          }
          set_dpi() { dpi_call setDPI "$1" "$2" >/dev/null || true; }
          get_dpi() {
            # ([1800, 1800],) → "1800 1800"
            local out
            out=$(dpi_call getDPI) && [[ "$out" =~ ([0-9]+)[,\ ]+([0-9]+) ]] || return 1
            echo "''${BASH_REMATCH[1]} ''${BASH_REMATCH[2]}"
          }

          restore() {
            [ -f "$prev_file" ] || return 0
            local px py
            read -r px py < "$prev_file" && set_dpi "$px" "$py"
            rm -f "$prev_file"
          }

          # Self-heal a leftover prev_file from a prior wrapper SIGKILLed
          # before its trap ran, so we never capture a game value as baseline.
          restore
          get_dpi > "$prev_file" || rm -f "$prev_file"
          set_dpi ${toString dpi} ${toString dpi}

          if [ -z "''${STEAM_COMPAT_INSTALL_PATH:-}" ]; then
            # Native game: the wrapped process is the game itself.
            trap restore EXIT INT TERM HUP
          else
            # Proton game: a launcher/anti-cheat outlives the game, so restore
            # once the game's own executables are all gone.
            mapfile -t exes < <(find "$STEAM_COMPAT_INSTALL_PATH" \
              -maxdepth 4 -iname '*.exe' -printf '%.15f\n' 2>/dev/null)
            game_running() {
              # comm is truncated to 15 chars; exe names were too (-printf %.15f).
              local e
              for e in "''${exes[@]}"; do pgrep -x "$e" >/dev/null 2>&1 && return 0; done
              return 1
            }
            (
              until game_running; do sleep 2; done
              while game_running; do sleep 2; done
              restore
            ) &
            watcher=$!
            trap 'kill "$watcher" 2>/dev/null || true; restore' EXIT INT TERM HUP
          fi

          "$@"
        '';
      }))
    ]
