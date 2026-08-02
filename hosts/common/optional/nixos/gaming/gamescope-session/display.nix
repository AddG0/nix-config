# Which monitor Gaming Mode runs on, and at what mode. Session lifecycle is in
# session.nix; this half only records a pick and turns it into gamescope flags.
# A plain function, not a module. The Decky plugin drives gamescope-set-display.
{
  pkgs,
  steamBin,
  marker,
  sessionFlag,
}: let
  # Not in XDG_RUNTIME_DIR: the pick has to outlive a reboot.
  displayState = ''"$HOME/.local/state/gamescope-display"'';

  # Keyed by connector — a mode valid on one monitor rarely is on another.
  modeState = ''"$HOME/.local/state/gamescope-display-modes"'';

  drmTools = ''
    drm=/sys/class/drm

    card_of() {
      local path base
      for path in "$drm"/card*-"$1"; do
        [ -e "$path/status" ] || continue
        base=''${path##*/}
        printf '%s' "''${base%%-*}"
        return 0
      done
      return 1
    }

    # modetest wants the DRM module while sysfs only knows the PCI driver, and
    # nvidia is the one place those two names differ.
    module_of() {
      local drv
      drv=$(basename "$(readlink -f "$drm/$1/device/driver")" 2>/dev/null) || return 1
      case $drv in
      nvidia) printf 'nvidia-drm' ;;
      *) printf '%s' "$drv" ;;
      esac
    }

    # An absent field is written "-", not left blank, or awk would see the next
    # column shift left. Columns: connector, WxH@Hz, comma-separated flags.
    field_for() {
      [ -s ${modeState} ] || return 0
      awk -v c="$1" -v n="$2" '$1 == c { if ($n != "-") print $n; exit }' ${modeState}
    }

    mode_for() { field_for "$1" 2; }
    flags_for() { field_for "$1" 3; }
  '';

  # gamescope opens one KMS card and which one follows its Vulkan device
  # (init_drm -> vulkan_primary_dev_id), so a dGPU connector is unreachable
  # unless --prefer-vk-device names that GPU.
  displayFlags = pkgs.writeShellApplication {
    name = "gamescope-display-flags";
    runtimeInputs = [pkgs.coreutils pkgs.gawk];
    text = ''
      ${drmTools}
      state=${displayState}
      [ -s "$state" ] || exit 0

      IFS=, read -ra want <"$state" || true

      # One name, not the whole list: gamescope would land on this one anyway,
      # having skipped the disconnected entries and never seen the ones on the
      # card it did not open.
      chosen=""
      picked=""
      for name in "''${want[@]}"; do
        card=$(card_of "$name") || continue
        [ "$(cat "$drm/$card-$name/status" 2>/dev/null)" = connected ] || continue
        chosen=$card
        picked=$name
        break
      done
      # All stored names unplugged: let gamescope choose over pinning a dead one.
      [ -n "$chosen" ] || exit 0

      printf -- '-O %s ' "$picked"

      # Either half of WxH@Hz may be empty — find_mode ignores a zero field, so
      # "@240" is any size at 240Hz — and it falls back to the connector default
      # when nothing matches. Validated digit by digit because ''${spec%@*} yields
      # the whole string when there is no @, which would hand gamescope a -r of
      # "2560x1600" and stop the session starting at all.
      spec=$(mode_for "$picked")
      res=""
      hz=""
      case $spec in
        *@*)
          res=''${spec%@*}
          hz=''${spec#*@}
          ;;
      esac
      case $hz in *[!0-9]*) hz="" ;; esac

      w=""
      h=""
      case $res in
        *x*)
          w=''${res%%x*}
          h=''${res#*x}
          case "$w$h" in "" | *[!0-9]*) w=""; h="" ;; esac
          ;;
      esac

      if [ -n "$w" ] && [ -n "$h" ]; then
        printf -- '-W %s -H %s ' "$w" "$h"
      fi
      if [ -n "$hz" ]; then
        printf -- '-r %s ' "$hz"
      fi

      flags=",$(flags_for "$picked"),"
      case $flags in *,vrr,*) printf -- '--adaptive-sync ' ;; esac
      case $flags in *,hdr,*) printf -- '--hdr-enabled ' ;; esac

      vendor=$(cat "$drm/$chosen/device/vendor" 2>/dev/null || true)
      device=$(cat "$drm/$chosen/device/device" 2>/dev/null || true)
      if [ -n "$vendor" ] && [ -n "$device" ]; then
        printf -- '--prefer-vk-device %s:%s' "''${vendor#0x}" "''${device#0x}"
      fi
      printf '\n'
    '';
  };

  # Takes a priority list, not one name: a pick that is unplugged later falls
  # through to the next instead of leaving gamescope with no output at all.
  setDisplay = pkgs.writeShellApplication {
    name = "gamescope-set-display";
    runtimeInputs = [pkgs.coreutils pkgs.glibc.bin pkgs.gnugrep pkgs.gawk pkgs.libdrm pkgs.edid-decode];
    text = ''
      # Adopt the live session owner's env before anything reads it: called from
      # a root shell or a root-flagged Decky plugin, $HOME and $XDG_RUNTIME_DIR
      # point at root and the flag check on /run/user/0 makes this a silent
      # no-op. Found by glob, so it switches whoever is gaming, not the caller.
      for f in /run/user/*/gamescope-session-active; do
        [ -e "$f" ] || continue
        rest=''${f#/run/user/}
        uid=''${rest%%/*}
        home=$(getent passwd "$uid" | cut -d: -f6) || continue
        [ -n "$home" ] || continue
        export HOME="$home" XDG_RUNTIME_DIR="/run/user/$uid"
        break
      done

      ${drmTools}
      state=${displayState}
      flag=${sessionFlag}
      next=${marker}

      case "''${1:-}" in
        --get)
          cat "$state" 2>/dev/null || true
          exit 0
          ;;
        --list)
          for c in /sys/class/drm/card*-*; do
            [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue
            n=''${c##*/}
            printf '%s\n' "''${n#*-}"
          done
          exit 0
          ;;
        # gamescope matches an integer vrefresh, so 60.00 and 59.94 collapse
        # to one entry.
        --modes)
          card=$(card_of "''${2:-}") || exit 0
          module=$(module_of "$card") || exit 0
          modetest -M "$module" -c 2>/dev/null | awk -v want="''${2:-}" '
            /^[0-9]+[ \t]/ { inc = ($4 == want) }
            inc && $1 ~ /^#[0-9]+$/ {
              split($2, d, "x")
              if (d[1] < 1280) next
              key = $2 "@" int($3 + 0.5)
              if (!(key in seen)) { seen[key] = 1; print key }
            }
          '
          exit 0
          ;;
        --get-mode)
          printf '%s\t%s\n' "$(mode_for "''${2:-}")" "$(flags_for "''${2:-}")"
          exit 0
          ;;
        # VRR is a connector property; HDR is only in the EDID, and a panel may
        # declare it in either a CTA metadata block or a DisplayID EOTF pair.
        --caps)
          card=$(card_of "''${2:-}") || exit 0
          module=$(module_of "$card") || exit 0
          vrr=$(modetest -M "$module" -c 2>/dev/null | awk -v want="''${2:-}" '
            /^[0-9]+[ \t]/ { inc = ($4 == want); seen = 0 }
            inc && /vrr_capable:/ { seen = 1; next }
            seen && $1 == "value:" { print $2; exit }
          ')
          hdr=0
          if edid-decode <"$drm/$card-''${2:-}/edid" 2>/dev/null |
            grep -qE "HDR Static Metadata|SMPTE ST 2084"; then
            hdr=1
          fi
          printf 'vrr=%s hdr=%s\n' "''${vrr:-0}" "$hdr"
          exit 0
          ;;
        # Write-only: the caller records a mode, then sets the display to restart.
        --mode)
          [ -n "''${2:-}" ] || exit 2
          spec=''${3:--}
          flags=''${4:--}
          mkdir -p "$(dirname ${modeState})"
          tmp=$(mktemp)
          grep -v "^''${2} " ${modeState} 2>/dev/null >"$tmp" || true
          if [ "$spec$flags" != "--" ]; then
            printf '%s %s %s\n' "''${2}" "$spec" "$flags" >>"$tmp"
          fi
          mv "$tmp" ${modeState}
          exit 0
          ;;
        # Both files: "automatic" means the screen and its mode.
        --clear)
          rm -f "$state" ${modeState}
          ;;
        "" | -*)
          echo "usage: gamescope-set-display <connector[,fallback...]> | --get | --list | --clear" >&2
          echo "       gamescope-set-display --modes <conn> | --caps <conn> | --get-mode <conn>" >&2
          echo "       gamescope-set-display --mode <conn> <WxH@Hz|-> [vrr,hdr|-]" >&2
          exit 2
          ;;
        *)
          mkdir -p "$(dirname "$state")"
          printf '%s\n' "$1" >"$state"
          ;;
      esac

      # Off the session, ending Steam would leave a marker that sends the next
      # desktop exit into Gaming Mode.
      if [ ! -e "$flag" ]; then
        echo "recorded; Gaming Mode is not running, so nothing to restart" >&2
        exit 0
      fi

      echo gamescope > "$next"
      exec ${steamBin} -shutdown
    '';
  };
in {
  inherit displayFlags setDisplay;
}
