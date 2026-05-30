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

      usage() {
        cat <<'EOF'
      Usage: monitor <subcommand> [name]

      Subcommands:
        list                List monitors known to Hyprland and their state.
        disable <name>      Save current spec then disable the monitor.
        enable <name>       Re-enable using saved spec, else preferred,auto.
        toggle <name>       Disable if active, enable if disabled.
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

      do_disable() {
        save_spec "$1"
        hyprctl keyword monitor "$1,disable"
      }

      do_enable() {
        local name="$1"
        local spec_file="$state_dir/$name.spec"
        if [[ -s "$spec_file" ]]; then
          hyprctl keyword monitor "$(cat "$spec_file")"
        else
          # No saved state — fall back to Hyprland's preferred mode and
          # let auto-positioning pick a column to the right of existing
          # outputs. Works for fresh hot-plug; user can `monitor recover`
          # afterwards to re-establish the declared layout.
          hyprctl keyword monitor "$name,preferred,auto,1"
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
                  echo "Monitors restored"''
        else ''          echo "monitor: no monitors declared in config; recover is a no-op" >&2
                  echo "Use 'monitor enable <name>' for ad-hoc restore." >&2
                  exit 1''
      }
      }

      cmd="''${1:-}"
      name="''${2:-}"

      case "$cmd" in
        list)
          # `monitors all` includes monitors currently configured as
          # disabled; the active set is `monitors`. Diff to label state.
          active=$(active_names | tr '\n' '|')
          while IFS= read -r m; do
            if [[ "|$active" == *"|$m|"* ]]; then
              printf '%-12s active\n' "$m"
            else
              printf '%-12s disabled\n' "$m"
            fi
          done < <(all_names)
          ;;
        disable)
          [[ -z "$name" ]] && { usage; exit 1; }
          if ! is_active "$name"; then
            echo "monitor: '$name' is already disabled" >&2
            exit 1
          fi
          do_disable "$name"
          ;;
        enable)
          [[ -z "$name" ]] && { usage; exit 1; }
          do_enable "$name"
          ;;
        toggle)
          [[ -z "$name" ]] && { usage; exit 1; }
          if is_active "$name"; then
            do_disable "$name"
          else
            do_enable "$name"
          fi
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

        if (( CURRENT == 3 )); then
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
        local prev="''${COMP_WORDS[COMP_CWORD-1]}"
        local subcmds="list disable enable toggle recover"

        if [ "$COMP_CWORD" -eq 1 ]; then
          mapfile -t COMPREPLY < <(compgen -W "$subcmds" -- "$cur")
          return 0
        fi

        case "$prev" in
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
