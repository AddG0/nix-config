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

  # Keyed by display — a mode valid on one monitor rarely is on another.
  modeState = ''"$HOME/.local/state/gamescope-display-modes"'';

  # Runtime, not state: it describes the running gamescope, not a preference.
  activeDisplay = ''"''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gamescope-display-active"'';

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
    # column shift left. Columns: id, WxH@Hz, comma-separated flags.
    field_for() {
      [ -s ${modeState} ] || return 0
      awk -v c="$1" -v n="$2" '$1 == c { if ($n != "-") print $n; exit }' ${modeState}
    }

    mode_for() { field_for "$1" 2; }
    flags_for() { field_for "$1" 3; }

    # Connector names move between ports and docks; the panel's EDID does not.
    # sysfs binary attributes report st_size 0, so this reads the file — `[ -s ]`
    # is false for a perfectly good EDID.
    display_id() {
      local dir=$1 conn=$2
      if [ "$(wc -c <"$dir/edid" 2>/dev/null || echo 0)" -gt 0 ]; then
        printf 'edid:%s' "$(sha256sum <"$dir/edid" | cut -c1-12)"
      else
        printf 'conn:%s' "$conn"
      fi
    }

    # id<TAB>connector, one line per connected output.
    outputs() {
      local dir base conn
      for dir in "$drm"/card*-*; do
        [ "$(cat "$dir/status" 2>/dev/null)" = connected ] || continue
        base=''${dir##*/}
        conn=''${base#*-}
        printf '%s\t%s\n' "$(display_id "$dir" "$conn")" "$conn"
      done
    }

    # Which port a stored display is plugged into now, if any.
    connector_for() {
      local want=$1 id conn
      while IFS=$'\t' read -r id conn; do
        [ "$id" = "$want" ] || continue
        printf '%s' "$conn"
        return 0
      done < <(outputs)
      return 1
    }

    # The panel's own name, so a picker need not say "DP-4".
    display_label() {
      local conn=$1 card name
      card=$(card_of "$conn") || { printf '%s' "$conn"; return 0; }
      name=$(edid-decode <"$drm/$card-$conn/edid" 2>/dev/null |
        awk -F"'" '/Display Product Name/ { gsub(/[[:space:]]+$/, "", $2); print $2; exit }')
      printf '%s' "''${name:-$conn}"
    }

    # The session holds this locked for as long as it runs, so taking the lock
    # means nobody is gaming — the file itself outlives a session killed hard.
    session_alive() {
      [ -e ${sessionFlag} ] || return 1
      ! flock -n ${sessionFlag} true 2>/dev/null
    }

    # The first stored display that is plugged in, empty if none are.
    preferred_display() {
      local want
      local -a list
      [ -s ${displayState} ] || return 0
      IFS=, read -ra list <${displayState} || return 0
      for want in "''${list[@]}"; do
        connector_for "$want" >/dev/null || continue
        printf '%s' "$want"
        return 0
      done
    }
  '';

  # gamescope opens one KMS card and which one follows its Vulkan device
  # (init_drm -> vulkan_primary_dev_id), so a dGPU connector is unreachable
  # unless --prefer-vk-device names that GPU.
  displayFlags = pkgs.writeShellApplication {
    name = "gamescope-display-flags";
    runtimeInputs = [pkgs.coreutils pkgs.gawk];
    text = ''
      ${drmTools}

      # One display, not the whole list: gamescope would land on this one anyway,
      # having skipped the disconnected entries and never seen the ones on the
      # card it did not open.
      active=$(preferred_display)
      # Every stored panel unplugged: let gamescope choose over pinning a dead one.
      [ -n "$active" ] || exit 0
      picked=$(connector_for "$active")
      chosen=$(card_of "$picked")

      # What the watcher rechecks on every hotplug.
      printf '%s\n' "$active" >${activeDisplay}

      printf -- '-O %s ' "$picked"

      # Either half of WxH@Hz may be empty — find_mode ignores a zero field, so
      # "@240" is any size at 240Hz — and it falls back to the connector default
      # when nothing matches. Validated digit by digit because ''${spec%@*} yields
      # the whole string when there is no @, which would hand gamescope a -r of
      # "2560x1600" and stop the session starting at all.
      spec=$(mode_for "$active")
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

      flags=",$(flags_for "$active"),"
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

  # gamescope keeps re-selecting the connector it already holds once that is
  # unplugged, so only a restart moves the session to a live screen. Runs for
  # the session's lifetime, started by session.nix alongside gamescope.
  watchDisplay = pkgs.writeShellApplication {
    name = "gamescope-watch-display";
    runtimeInputs = [pkgs.coreutils pkgs.util-linux pkgs.systemd];
    text = ''
      ${drmTools}

      active=$(cat ${activeDisplay} 2>/dev/null || true)
      [ -n "$active" ] || exit 0

      # $! after a process substitution is the monitor, so it dies with us
      # instead of lingering until its next write.
      exec 3< <(udevadm monitor --udev --subsystem-match=drm)
      monitor=$!
      trap 'kill "$monitor" 2>/dev/null || true' EXIT

      while read -r _ <&3; do
        # Connector status lags the event, and one unplug emits a burst; the
        # wait coalesces them.
        sleep 2
        connector_for "$active" >/dev/null && continue
        # Nothing live to fall through to; a restart would only black out again.
        [ -n "$(preferred_display)" ] || continue
        echo gamescope > ${marker}
        exec ${steamBin} -shutdown
      done
    '';
  };

  # Takes a priority list, not one name: a pick that is unplugged later falls
  # through to the next instead of leaving gamescope with no output at all.
  setDisplay = pkgs.writeShellApplication {
    name = "gamescope-set-display";
    runtimeInputs = [pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.libdrm pkgs.edid-decode pkgs.util-linux];
    text = ''
      # Every path reads $HOME or $XDG_RUNTIME_DIR and ends in `steam -shutdown`,
      # which Steam refuses to run as root.
      if [ "$(id -u)" = 0 ]; then
        echo "run as the session owner, not root" >&2
        exit 1
      fi

      ${drmTools}
      state=${displayState}
      next=${marker}

      case "''${1:-}" in
        --get)
          cat "$state" 2>/dev/null || true
          exit 0
          ;;
        # id<TAB>label<TAB>internal, so the picker shows the panel, stores the id.
        # Empty when the pick was unplugged and gamescope chose for itself.
        --active)
          cat ${activeDisplay} 2>/dev/null || true
          exit 0
          ;;
        --list)
          while IFS=$'\t' read -r id conn; do
            case $conn in
              eDP* | LVDS* | DSI*) internal=1 ;;
              *) internal=0 ;;
            esac
            printf '%s\t%s\t%s\n' "$id" "$(display_label "$conn")" "$internal"
          done < <(outputs)
          exit 0
          ;;
        # gamescope matches an integer vrefresh, so 60.00 and 59.94 collapse
        # to one entry.
        --modes)
          conn=$(connector_for "''${2:-}") || exit 0
          card=$(card_of "$conn") || exit 0
          module=$(module_of "$card") || exit 0
          modetest -M "$module" -c 2>/dev/null | awk -v want="$conn" '
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
          conn=$(connector_for "''${2:-}") || exit 0
          card=$(card_of "$conn") || exit 0
          module=$(module_of "$card") || exit 0
          vrr=$(modetest -M "$module" -c 2>/dev/null | awk -v want="$conn" '
            /^[0-9]+[ \t]/ { inc = ($4 == want); seen = 0 }
            inc && /vrr_capable:/ { seen = 1; next }
            seen && $1 == "value:" { print $2; exit }
          ')
          hdr=0
          if edid-decode <"$drm/$card-$conn/edid" 2>/dev/null |
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
          echo "usage: gamescope-set-display <display[,fallback...]> | --get | --active | --list | --clear" >&2
          echo "       gamescope-set-display --modes <id> | --caps <id> | --get-mode <id>" >&2
          echo "       gamescope-set-display --mode <id> <WxH@Hz|-> [vrr,hdr|-]" >&2
          exit 2
          ;;
        # An id that resolves to nothing is kept, not rejected: the panel may be
        # plugged back in.
        *)
          mkdir -p "$(dirname "$state")"
          printf '%s\n' "$1" >"$state"
          ;;
      esac

      # Off the session, ending Steam would leave a marker that sends the next
      # desktop exit into Gaming Mode.
      if ! session_alive; then
        echo "recorded; Gaming Mode is not running, so nothing to restart" >&2
        exit 0
      fi

      echo gamescope > "$next"

      exec ${steamBin} -shutdown
    '';
  };
in {
  inherit displayFlags setDisplay watchDisplay;
}
