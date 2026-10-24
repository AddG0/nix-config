# Steam wrapper that asks before launching without a physical gamepad; virtual input devices live under /devices/virtual.
{
  lib,
  pkgs,
}: game:
lib.getExe (pkgs.writeShellApplication {
  name = "require-controller";
  runtimeInputs = [pkgs.coreutils pkgs.gawk pkgs.zenity];
  text = ''
    # Needs Steam Input's pad too: it lands seconds after the physical one, and a running game takes it as a second player.
    # It is matched by name, since keyd's virtual pointer also has a js node.
    pads_ready() {
      awk -v need="$1" '/^N: Name=/ { steam = ($0 ~ /X-Box 360 pad/) }
           /^S: Sysfs=/ { virt = ($0 ~ /\/virtual\//) }
           /^H: Handlers=/ && / js[0-9]+/ { if (!virt) physical = 1; else if (steam) input = 1 }
           END { exit !(physical && (need == "physical" || input)) }' /proc/bus/input/devices
    }

    if pads_ready both; then
      exec "$@"
    fi

    # Steam's LD_LIBRARY_PATH pins an old libcurl that stops zenity loading, and that failure exits 1 like Cancel.
    env -u LD_LIBRARY_PATH -u LD_PRELOAD zenity --question --title=${lib.escapeShellArg game} \
      --text=${lib.escapeShellArg "No controller connected.\nPlug one in to start."} \
      --ok-label=Start --cancel-label=Cancel &
    dialog=$!

    while kill -0 "$dialog" 2>/dev/null; do
      # Steam creates its pad only once the game process exists, so a pad plugged in here never gets one.
      if pads_ready physical; then
        sleep 5
        kill "$dialog" 2>/dev/null || true
        exec "$@"
      fi
      sleep 0.5
    done

    rc=0
    wait "$dialog" || rc=$?
    case $rc in
      0) exec "$@" ;;
      1) exit 0 ;;
      *) echo "require-controller: zenity exited $rc; launching ${game} without asking" >&2
         exec "$@" ;;
    esac
  '';
})
