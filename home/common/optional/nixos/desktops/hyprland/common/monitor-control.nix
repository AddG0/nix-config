{
  pkgs,
  lib,
  config,
  ...
}: let
  hyprLib = import ./lib.nix;
  transformToHyprland = hyprLib.transformMap;
  vrrToHyprland = hyprLib.vrrMap;

  # ---------- recover-mode baked layout (declared, not runtime) ----------
  # Only `recover` reads these — everyday list/disable/enable/toggle use
  # `hyprctl` so freshly hot-plugged monitors work without a rebuild.
  monitorSpec = m: "${toString m.width}x${toString m.height}@${toString m.refreshRate}.0,${toString m.x}x${toString m.y},${toString m.scale},transform,${toString transformToHyprland.${m.transform}},vrr,${toString vrrToHyprland.${m.vrr}}${
    lib.optionalString (m.bitdepth != 8) ",bitdepth,${toString m.bitdepth}"
  }${
    lib.optionalString m.hdr ",cm,hdr"
  }";

  restoreMonitors =
    lib.concatMapStringsSep "\n          "
    (m: ''hyprctl keyword monitor ${lib.escapeShellArg "${m.output},${monitorSpec m}"}'')
    config.display.monitors;

  # Parse "1, monitor:DP-3, default:true" → { ws = "1"; mon = "DP-3"; }
  wsRules = let
    rules = config.wayland.windowManager.hyprland.settings.workspace or [];
    parseRule = rule: let
      parts = lib.splitString "," rule;
      wsId = lib.trim (builtins.head parts);
      monPart = lib.findFirst (p: lib.hasPrefix "monitor:" (lib.trim p)) null (builtins.tail parts);
      mon =
        if monPart != null
        then lib.removePrefix "monitor:" (lib.trim monPart)
        else null;
    in
      if mon != null
      then {
        ws = wsId;
        inherit mon;
      }
      else null;
  in
    builtins.filter (x: x != null) (map parseRule rules);

  configuredWsIds = map (r: r.ws) wsRules;

  moveConfiguredWs =
    lib.concatMapStringsSep "\n          "
    (r: ''hyprctl dispatch moveworkspacetomonitor ${r.ws} ${r.mon}'')
    wsRules;

  configuredPattern = lib.concatStringsSep "|" configuredWsIds;

  primaryNames = map (m: m.output) (builtins.filter (m: m.primary) config.display.monitors);
  primaryMon =
    if primaryNames != []
    then builtins.head primaryNames
    else "";

  hasDeclaredMonitors = config.display.monitors != [];

  # ---------- runtime helpers shared by main script and completion ----------
  # Build a full `monitor` keyword spec from a hyprctl JSON entry. Covers
  # resolution, position, scale, transform, VRR, 10-bit, and HDR — anything
  # else (mirror, custom modes) isn't reflected in hyprctl JSON anyway.
  specFromJqExpr = ''
    "\(.name),\(.width)x\(.height)@\(.refreshRate),\(.x)x\(.y),\(.scale),transform,\(.transform),vrr,\(if .vrr then 1 else 0 end)"
    + (if (.currentFormat // "") | test("10") then ",bitdepth,10" else "" end)
    + (if (.colorManagementPreset // "") == "hdr" then ",cm,hdr" else "" end)
  '';

  monitor-bin = pkgs.writeShellApplication {
    name = "monitor";
    runtimeInputs = with pkgs; [hyprland jq coreutils];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-monitor-control"
      mkdir -p "$state_dir"

      if [[ -t 1 ]] && [[ -z "''${NO_COLOR:-}" ]]; then
        c_ok=$'\033[32m'; c_err=$'\033[31m'
        c_dim=$'\033[2m'; c_reset=$'\033[0m'
      else
        c_ok=""; c_err=""; c_dim=""; c_reset=""
      fi

      ok()   { printf '%s✓%s %s\n' "$c_ok" "$c_reset" "$*"; }
      skip() { printf '%s•%s %s\n' "$c_dim" "$c_reset" "$*" >&2; }
      err()  { printf '%s✗%s %s\n' "$c_err" "$c_reset" "$*" >&2; }

      usage() {
        cat <<'EOF'
      Usage: monitor <subcommand> [name...]

      Subcommands:
        list                List monitors known to Hyprland and their state.
        disable <name...>   Save current spec then disable the monitor(s).
                            Refuses the last active monitor; -f to force.
        enable <name...>    Re-enable using saved spec, else preferred,auto.
        toggle <name...>    Disable if active, enable if disabled.
        recover             Re-apply declared layout and reflow workspaces.
                            Use when runtime state is wedged (hot-plug
                            glitch, crashed sunshine session, etc).
      EOF
      }

      active_names() {
        hyprctl monitors -j | jq -r '.[].name'
      }

      all_names() {
        hyprctl monitors all -j | jq -r '.[].name'
      }

      is_active() {
        hyprctl monitors -j | jq -e --arg n "$1" 'map(select(.name == $n)) | length > 0' >/dev/null
      }

      active_count() {
        hyprctl monitors -j | jq 'length'
      }

      # Known to Hyprland at all (active or configured-disabled).
      is_known() {
        hyprctl monitors all -j | jq -e --arg n "$1" 'any(.[]; .name == $n)' >/dev/null
      }

      # Hint listing every name Hyprland currently reports, for typos.
      known_hint() {
        local names
        names=$(all_names | tr '\n' ' ')
        [[ -n "$names" ]] && echo "  known monitors: $names" >&2 || true
      }

      save_spec() {
        local name="$1"
        local spec
        spec=$(hyprctl monitors -j | jq -r --arg n "$name" '
          .[] | select(.name == $n) | ${lib.replaceStrings ["\n"] [" "] specFromJqExpr}
        ')
        if [[ -n "$spec" ]]; then
          printf '%s\n' "$spec" > "$state_dir/$name.spec"
        fi
      }

      # Apply a monitor keyword spec, swallowing hyprctl's raw "ok" and
      # surfacing any error under our own formatting. $1 = monitor name
      # (for messages), $2 = full keyword spec.
      apply_spec() {
        local out
        out=$(hyprctl keyword monitor "$2" 2>&1)
        if [[ "$out" == "ok" ]]; then
          return 0
        fi
        err "$1: ''${out:-hyprctl failed}"
        return 1
      }

      do_disable() {
        # Refuse to black out the last display unless forced — recovering
        # from zero active monitors means blind keybinds or a TTY.
        if [[ "''${force:-0}" != 1 ]] && (( $(active_count) <= 1 )); then
          err "$1 is the last active monitor; refusing (use 'disable -f' to force)"
          return 1
        fi
        save_spec "$1"
        apply_spec "$1" "$1,disable" || return 1
        ok "$1 disabled"
      }

      do_enable() {
        local name="$1"
        local spec_file="$state_dir/$name.spec"
        if [[ -s "$spec_file" ]]; then
          apply_spec "$name" "$(cat "$spec_file")" || return 1
          ok "$name enabled (restored saved layout)"
        else
          # No saved state — fall back to Hyprland's preferred mode and
          # let auto-positioning pick a column to the right of existing
          # outputs. Works for fresh hot-plug; user can `monitor recover`
          # afterwards to re-establish the declared layout.
          apply_spec "$name" "$name,preferred,auto,1" || return 1
          ok "$name enabled (preferred mode, auto-positioned)"
        fi
      }

      do_recover() {
        ${
        if hasDeclaredMonitors
        then ''          # Re-apply every declared monitor with its baked spec.
                  ${restoreMonitors}
                  sleep 2

                  # Move configured workspaces back to their assigned monitors.
                  ${moveConfiguredWs}

                  # Sweep any remaining workspaces onto the primary monitor.
                  ${
            if primaryMon == ""
            then '': # no primary declared; skipping orphan-workspace sweep''
            else if configuredWsIds != []
            then ''              for ws in $(hyprctl -j workspaces | jq -r '.[].id'); do
                                case "$ws" in
                                  ${configuredPattern}) ;;
                                  *) hyprctl dispatch moveworkspacetomonitor "$ws" "${primaryMon}" ;;
                                esac
                              done''
            else ''              for ws in $(hyprctl -j workspaces | jq -r '.[].id'); do
                                hyprctl dispatch moveworkspacetomonitor "$ws" "${primaryMon}"
                              done''
          }
                  ok "monitors restored"''
        else ''          err "no monitors declared in config; recover is a no-op"
                  echo "  use 'monitor enable <name>' for ad-hoc restore." >&2
                  exit 1''
      }
      }

      cmd="''${1:-}"

      case "$cmd" in
        list)
          # `monitors all` includes monitors currently configured as
          # disabled; the active set is `monitors`. Diff to label state.
          active=$(active_names | tr '\n' '|')
          while IFS=$'\t' read -r m model res; do
            if [[ "|$active|" == *"|$m|"* ]]; then
              state="active"; col="$c_ok"
            else
              state="disabled"; col="$c_dim"
            fi
            # Pad before coloring so escape codes don't break alignment.
            printf -v statecol '%-8s' "$state"
            printf '%-12s %s%s%s  %s%s  %s\n' \
              "$m" "$col" "$statecol" "$c_reset" "$c_dim" "$model" "$res$c_reset"
          done < <(hyprctl monitors all -j | jq -r '
            .[] | "\(.name)\t\(.model // .description // "?")\t\(.width)x\(.height)@\(.refreshRate | floor)Hz"
          ')
          ;;
        disable)
          shift
          force=0
          names=()
          for a in "$@"; do
            case "$a" in
              -f | --force) force=1 ;;
              *) names+=("$a") ;;
            esac
          done
          [[ ''${#names[@]} -eq 0 ]] && { usage; exit 1; }
          rc=0
          for name in "''${names[@]}"; do
            if is_active "$name"; then
              do_disable "$name" || rc=1
            elif is_known "$name"; then
              skip "$name already disabled"
            else
              err "unknown monitor '$name'"
              known_hint
              rc=1
            fi
          done
          exit "$rc"
          ;;
        enable)
          [[ $# -lt 2 ]] && { usage; exit 1; }
          rc=0
          for name in "''${@:2}"; do
            if is_active "$name"; then
              skip "$name already enabled"
            else
              do_enable "$name" || rc=1
            fi
          done
          exit "$rc"
          ;;
        toggle)
          [[ $# -lt 2 ]] && { usage; exit 1; }
          rc=0
          for name in "''${@:2}"; do
            if is_active "$name"; then
              do_disable "$name" || rc=1
            else
              do_enable "$name" || rc=1
            fi
          done
          exit "$rc"
          ;;
        recover)
          do_recover
          ;;
        ""|-h|--help|help)
          usage
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    '';
  };

  monitor-completion-zsh = pkgs.writeTextFile {
    name = "monitor-zsh-completion";
    destination = "/share/zsh/site-functions/_monitor";
    text = ''
      #compdef monitor

      # Build "name:label" pairs from hyprctl JSON. The label combines model
      # + resolution so the completion menu reads like "DP-1  -- ROG PG32UQX
      # 3840x2160@144Hz". A two-pass filter computes the max model width so
      # the resolution column aligns across all rows.
      _monitor_describe_filter='
        . as $all
        | ($all | map(((.model // .description // "?") | gsub(":";"")) | length) | max) as $w
        | .[]
        | ((.model // .description // "?") | gsub(":";"")) as $m
        | "\(.name):" + $m + ((" " * ($w - ($m | length))) // "")
          + "  \(.width)x\(.height)@\(.refreshRate | floor)Hz"
      '

      _monitor() {
        local -a subcmds
        subcmds=(
          'list:Show monitor states'
          'disable:Save spec and disable a monitor'
          'enable:Re-enable a monitor from saved spec'
          'toggle:Toggle a monitor active/disabled'
          'recover:Re-apply declared layout and reflow workspaces'
        )

        if (( CURRENT == 2 )); then
          _describe 'subcommand' subcmds
          return
        fi

        if (( CURRENT >= 3 )); then
          case "$words[2]" in
            disable|toggle)
              # `monitors` (active set) — fine for disable/toggle.
              local -a active
              active=(''${(f)"$(hyprctl monitors -j 2>/dev/null | jq -r "$_monitor_describe_filter")"})
              _describe -V 'active monitor' active
              ;;
            enable)
              # Only offer monitors currently disabled (from `monitors all`)
              # plus any saved-spec names hyprctl doesn't know about.
              local -a disabled
              disabled=(''${(f)"$(hyprctl monitors all -j 2>/dev/null | jq -r "map(select(.disabled == true)) | $_monitor_describe_filter")"})
              local state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-monitor-control"
              if [[ -d "$state_dir" ]]; then
                local f n active_pat
                # Names hyprctl currently reports as active — exclude these.
                active_pat="$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' | tr '\n' '|')"
                for f in "$state_dir"/*.spec(N); do
                  n="''${''${f:t}%.spec}"
                  # Skip if already in the disabled list or currently active.
                  if print -l -- "''${disabled[@]}" | grep -q "^''${n}:"; then continue; fi
                  if [[ "|$active_pat" == *"|$n|"* ]]; then continue; fi
                  disabled+=("''${n}:(saved spec)")
                done
              fi
              if (( ''${#disabled[@]} == 0 )); then
                _message 'no disabled monitors'
              else
                _describe -V 'disabled monitor' disabled
              fi
              ;;
          esac
        fi
      }

      _monitor "$@"
    '';
  };

  monitor-completion-bash = pkgs.writeTextFile {
    name = "monitor-bash-completion";
    destination = "/share/bash-completion/completions/monitor";
    text = ''
      _monitor_complete() {
        local cur="''${COMP_WORDS[COMP_CWORD]}"
        local subcmd="''${COMP_WORDS[1]}"
        local subcmds="list disable enable toggle recover"

        if [ "$COMP_CWORD" -eq 1 ]; then
          mapfile -t COMPREPLY < <(compgen -W "$subcmds" -- "$cur")
          return 0
        fi

        case "$subcmd" in
          disable|toggle)
            local mons
            mons=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name')
            mapfile -t COMPREPLY < <(compgen -W "$mons" -- "$cur")
            ;;
          enable)
            local mons active
            mons=$(hyprctl monitors all -j 2>/dev/null | jq -r '.[] | select(.disabled == true) | .name')
            active=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' | tr '\n' '|')
            local state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-monitor-control"
            if [ -d "$state_dir" ]; then
              local f n
              for f in "$state_dir"/*.spec; do
                [ -e "$f" ] || continue
                n=$(basename "$f" .spec)
                # Skip if currently active.
                case "|$active" in *"|$n|"*) continue ;; esac
                mons="$mons"$'\n'"$n"
              done
            fi
            mons=$(printf '%s\n' "$mons" | awk 'NF && !seen[$0]++')
            mapfile -t COMPREPLY < <(compgen -W "$mons" -- "$cur")
            ;;
        esac
      }
      complete -F _monitor_complete monitor
    '';
  };

  monitor = pkgs.symlinkJoin {
    name = "monitor";
    paths = [monitor-bin monitor-completion-zsh monitor-completion-bash];
  };
in {
  home.packages = [monitor];

  # Safety keybind: re-apply the declared monitor layout if runtime state
  # is wedged (crashed sunshine session, hot-plug glitch, etc).
  # Owns SUPERSHIFT+S — sunshine.nix's bind for the same key was removed
  # so the two don't clobber each other. `sunshine-disconnect` is still
  # invoked by Sunshine's own service hook on normal disconnects, and
  # remains runnable from a shell for headless/noctalia cleanup.
  wayland.windowManager.hyprland.settings.bind = [
    "SUPERSHIFT,r,exec,${monitor}/bin/monitor recover"
  ];
}
