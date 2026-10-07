{
  baseDir,
  cfg,
  lib,
  pkgs,
  resolvedProfiles,
}: let
  pluginDirsCase = lib.concatStringsSep "\n" (lib.mapAttrsToList (
      name: _profile: let
        resolved = resolvedProfiles.${name};
        dirs = resolved.pluginDirs or [];
      in
        lib.optionalString (dirs != []) ''
          ${name}) ${lib.concatMapStringsSep " " (d: ''PLUGIN_ARGS+=(--plugin-dir "${d}")'') dirs} ;;''
    )
    cfg.profiles);

  wrapperScript = pkgs.writeShellScriptBin "claude" ''
    ${lib.optionalString (pkgs.stdenv.hostPlatform.isLinux && cfg.captureNode != null)
      "export PIPEWIRE_NODE=${lib.escapeShellArg cfg.captureNode}"}
    ${lib.optionalString (cfg.unsetEnv != []) "unset ${lib.escapeShellArgs cfg.unsetEnv}"}
    PROFILE="${cfg.defaultProfile}"
    ARGS=()
    SESSION_ARGS=()

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

    ${lib.optionalString (cfg.conditionalSettings != null) ''
      if [[ ''${#ARGS[@]} -ne 1 || ''${ARGS[0]} != --version ]] && ${cfg.conditionalSettings.command}; then
        SESSION_ARGS+=(--settings ${lib.escapeShellArg cfg.conditionalSettings.file})
      fi
    ''}

    exec ${cfg.package}/bin/claude "''${SESSION_ARGS[@]}" "''${MCP_ARGS[@]}" "''${PLUGIN_ARGS[@]}" "''${ARGS[@]}"
  '';
in {
  inherit pluginDirsCase wrapperScript;
}
