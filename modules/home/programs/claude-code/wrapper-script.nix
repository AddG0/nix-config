{
  baseDir,
  cfg,
  lib,
  pkgs,
  pluginCheck,
  resolvedProfiles,
}: let
  pluginDirsCase = lib.concatStringsSep "\n" (lib.mapAttrsToList (
      name: _profile: let
        resolved = resolvedProfiles.${name};
        dirs = map pluginCheck.pluginDir (resolved.pluginDirs or []);
      in
        lib.optionalString (dirs != []) ''
          ${name}) ${lib.concatMapStringsSep " " (d: ''PLUGIN_ARGS+=(--plugin-dir "${d}")'') dirs} ;;''
    )
    cfg.profiles);

  wrapperScript = pkgs.writeShellScriptBin "claude" ''
    ${lib.optionalString (pkgs.stdenv.hostPlatform.isLinux && cfg.captureNode != null)
      "export PIPEWIRE_NODE=${lib.escapeShellArg cfg.captureNode}"}
    ${lib.optionalString (cfg.unsetEnv != []) "unset ${lib.escapeShellArgs cfg.unsetEnv}"}
    ${lib.optionalString (cfg.extraPath != []) "export PATH=${lib.makeBinPath cfg.extraPath}:$PATH"}
    PROFILE="${cfg.defaultProfile}"
    ARGS=()
    SESSION_ARGS=()
    CALLER_SETTINGS=()

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --profile|-P)
          if [[ -n "$2" && ! "$2" =~ ^- ]]; then
            PROFILE="$2"
            shift 2
          else
            echo "Error: --profile requires a profile name" >&2
            exit 1
          fi
          ;;
        --profile=*) PROFILE="''${1#--profile=}"; shift ;;
        -P=*) PROFILE="''${1#-P=}"; shift ;;
        --list-profiles)
          echo "Available profiles:"
          for dir in "$HOME/${baseDir}"/*/; do
            [ -d "$dir" ] && echo "  - $(basename "$dir")"
          done
          exit 0
          ;;
        ${lib.optionalString (cfg.conditionalSettings != null) ''
      --settings) CALLER_SETTINGS+=("$2"); shift 2 ;;
      --settings=*) CALLER_SETTINGS+=("''${1#--settings=}"); shift ;;
    ''}
        *) ARGS+=("$1"); shift ;;
      esac
    done

    PROFILE_DIR="$HOME/${baseDir}/$PROFILE"

    if [[ ! -d "$PROFILE_DIR" ]]; then
      echo "Error: Profile '$PROFILE' not found at $PROFILE_DIR" >&2
      echo "Available profiles:"
      for dir in "$HOME/${baseDir}"/*/; do
        [ -d "$dir" ] && echo "  - $(basename "$dir")"
      done
      exit 1
    fi

    export CLAUDE_CONFIG_DIR="$PROFILE_DIR"

    MCP_ARGS=()
    if [[ -f "$PROFILE_DIR/.mcp.json" ]]; then
      MCP_ARGS+=(--mcp-config "$PROFILE_DIR/.mcp.json")
    fi

    PLUGIN_ARGS=()
    case "$PROFILE" in
    ${pluginDirsCase}
      *) ;;
    esac

    if [[ -d "$PROFILE_DIR/plugins/lsp" ]]; then
      PLUGIN_ARGS+=(--plugin-dir "$PROFILE_DIR/plugins/lsp")
    fi

    SESSION_SETTINGS=skipped
    ${lib.optionalString (cfg.conditionalSettings != null) ''
      CONDITIONAL_STATUS=1
      if [[ ''${#ARGS[@]} -ne 1 || ''${ARGS[0]} != --version ]]; then
        CONDITIONAL_STATUS=0
        CONDITIONAL=$(${cfg.conditionalSettings.command}) || CONDITIONAL_STATUS=$?
      fi
      # 2 is a broken config, which starting without the settings would hide.
      if [[ $CONDITIONAL_STATUS == 2 ]]; then
        echo "claude wrapper: ${cfg.conditionalSettings.command} reported a broken config, so the session does not start" >&2
        exit 2
      fi
      # Claude keeps only the last --settings, so a caller's (the Agent SDK passes one) would drop ours.
      if [[ $CONDITIONAL_STATUS == 0 ]]; then
        SESSION_SETTINGS=applied
        SOURCES=(${lib.escapeShellArg cfg.conditionalSettings.file})
        [[ -z $CONDITIONAL ]] || SOURCES+=("$CONDITIONAL")
        MERGED=$(set -o pipefail; for s in "''${SOURCES[@]}" "''${CALLER_SETTINGS[@]}"; do
          if [[ $s == "{"* ]]; then printf '%s\n' "$s"; else cat -- "$s" || exit 1; fi
        done | ${lib.getExe pkgs.jq} -cs 'reduce .[] as $s ({}; . * $s)') || {
          echo "claude wrapper: cannot merge --settings ''${CALLER_SETTINGS[*]}''${CONDITIONAL:+ and the output of ${cfg.conditionalSettings.command}: $CONDITIONAL} into ${cfg.conditionalSettings.file}" >&2
          exit 1
        }
        SESSION_ARGS+=(--settings "$MERGED")
      else
        for s in "''${CALLER_SETTINGS[@]}"; do
          SESSION_ARGS+=(--settings "$s")
        done
      fi
    ''}

    ${lib.optionalString (cfg.sessionAttributes != null) ''
      if [[ ''${#ARGS[@]} -ne 1 || ''${ARGS[0]} != --version ]]; then
        ATTRIBUTES_STATUS=0
        ATTRIBUTES=$(CLAUDE_SESSION_SETTINGS=$SESSION_SETTINGS ${cfg.sessionAttributes}) || ATTRIBUTES_STATUS=$?
        if [[ $ATTRIBUTES_STATUS == 2 ]]; then
          echo "claude wrapper: ${cfg.sessionAttributes} reported a broken config, so the session does not start" >&2
          exit 2
        elif [[ $ATTRIBUTES_STATUS == 0 && -n $ATTRIBUTES ]]; then
          export OTEL_RESOURCE_ATTRIBUTES="''${OTEL_RESOURCE_ATTRIBUTES:+$OTEL_RESOURCE_ATTRIBUTES,}$ATTRIBUTES"
        else
          echo "claude wrapper: ${cfg.sessionAttributes} gave no session attributes, so this session's telemetry is untagged" >&2
        fi
      fi
    ''}

    exec ${cfg.package}/bin/claude "''${SESSION_ARGS[@]}" "''${MCP_ARGS[@]}" "''${PLUGIN_ARGS[@]}" "''${ARGS[@]}"
  '';
in {
  inherit pluginDirsCase wrapperScript;
}
